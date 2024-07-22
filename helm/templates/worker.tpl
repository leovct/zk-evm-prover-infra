apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-init-circuits
spec:
  template:
    spec:
      containers:
      - name: init-circuits
        image: {{ .Values.jumpbox.image }}
        command: ["/bin/sh", "/scripts/init-circuits.sh"]
        envFrom:
        - configMapRef:
            name: {{ .Release.Name }}-worker-cm
        volumeMounts:
        - name: init-scripts
          mountPath: /scripts
        - name: circuits
          mountPath: /circuits
      restartPolicy: OnFailure
      volumes:
      - name: init-scripts
        configMap:
          name: {{ .Release.Name }}-circuits-init-scripts
      - name: circuits
        persistentVolumeClaim:
          claimName: {{ .Release.Name }}-worker-circuits-pvc
      nodeSelector:
        cloud.google.com/gke-nodepool: highmem-node-pool
      tolerations:
      - key: "highmem"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-circuits-init-scripts
data:
  init-circuits.sh: |
    #!/bin/sh

    # Check if the circuits are already initialized
    if [ -f /circuits/.initialized ]; then
      echo "Circuits already initialized"
      exit 0
    fi

    # Run the worker command in the background and capture its output
    worker {{ join " " .Values.worker.flags }} 2>&1 | tee /tmp/worker.log &
    WORKER_PID=$!

    SUCCESS_MESSAGE1="saving preprocessed circuits to disk"
    SUCCESS_MESSAGE2="successfully loaded preprocessed circuits from disk"
    while true; do
      if grep -q "$SUCCESS_MESSAGE1" /tmp/worker.log || grep -q "$SUCCESS_MESSAGE2" /tmp/worker.log; then
        sleep 20
        echo "Circuits initialization complete"
        touch /circuits/.initialized
        exit 0
      fi
      if ! ps -p $WORKER_PID > /dev/null; then
        echo "Worker process terminated unexpectedly"
        exit 1
      fi
      sleep 10
    done


---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-zk-evm-worker
spec:
  # The number of replicas should be set to one as it is managed by the HPA.
  replicas: {{ if .Values.worker.autoscaler }}1{{- else }}{{ .Values.worker.minWorkerCount }}{{- end }}
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      initContainers:
      - name: check-initialization
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
          while [ ! -f /circuits/.initialized ]; do
            echo "Waiting for circuits initialization to complete..."
            sleep 10
          done
          echo "Circuits initialization complete"
        volumeMounts:
        - name: circuits
          mountPath: /circuits

      containers:
      - name: worker
        image: {{ .Values.zk_evm_image }}
        command: ["worker"]
        args:
        {{- with .Values.worker.flags }}
        {{- range . }}
        - {{ . }}
        {{- end }}
        {{- end }}
        envFrom:
        - configMapRef:
            name: {{ .Release.Name }}-worker-cm
        volumeMounts:
        - name: circuits
          mountPath: /circuits
        # TODO: Remove this after testing.
        securityContext:
          runAsUser: 0
        resources:
          requests:
            memory: {{ .Values.worker.resources.requests.memory }}
            cpu: {{ .Values.worker.resources.requests.cpu }}
          limits:
            memory: {{ .Values.worker.resources.limits.memory }}
            cpu: {{ .Values.worker.resources.limits.cpu }}
      volumes:
      - name: circuits
        persistentVolumeClaim:
          claimName: {{ .Release.Name }}-worker-circuits-pvc
      nodeSelector:
        cloud.google.com/gke-nodepool: highmem-node-pool
      tolerations:
      - key: "highmem"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-worker-cm
data:
  AMQP_URI: {{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace }}
  {{- range $key, $value := .Values.worker.env }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}


---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-worker-circuits-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
