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
        echo Waiting 4 minutes to save circuits to disk...
        sleep 240

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
