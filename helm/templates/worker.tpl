apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-zk-evm-worker
spec:
  # The number of replicas should be set to zero (or one?) as it is managed by the HPA.
  replicas: {{ if .Values.worker.autoscaler }}1{{- else }}{{ .Values.worker.minWorkerCount }}{{- end }}
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: {{ .Values.zk_evm_image }}
        command: ["worker"]
        args:
        - "--runtime=amqp"
        env:
        - name: AMQP_URI
          value: {{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace }}
        - name: RUST_BACKTRACE
          value: full
        - name: RUST_LOG
          value: info
        - name: RUST_MIN_STACK
          value: "33554432"
        - name: ARITHMETIC_CIRCUIT_SIZE
          value: "15..28"
        - name: BYTE_PACKING_CIRCUIT_SIZE
          value: "9..28"
        - name: CPU_CIRCUIT_SIZE
          value: "12..28"
        - name: KECCAK_CIRCUIT_SIZE
          value: "14..28"
        - name: KECCAK_SPONGE_CIRCUIT_SIZE
          value: "9..28"
        - name: LOGIC_CIRCUIT_SIZE
          value: "12..28"
        - name: MEMORY_CIRCUIT_SIZE
          value: "17..30"
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
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-worker-circuits-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
