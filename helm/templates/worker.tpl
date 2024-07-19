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
      containers:
      - name: worker
        image: {{ .Values.zk_evm_image }}
        command: ["worker"]
        args:
        - "--serializer=postcard"
        - "--runtime=amqp"
        - "--persistence=disk"
        - "--load-strategy=on-demand"
        env:
        - name: AMQP_URI
          value: {{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace }}
        - name: RUST_BACKTRACE
          value: full
        - name: RUST_LOG
          value: info
        - name: RUST_MIN_STACK
          value: "33554432"
        # Recommended circuit sizes by Robin.
        # https://0xpolygon.slack.com/archives/C0772FWR8D7/p1721390017860929?thread_ts=1721348826.760799&cid=C0772FWR8D7
        - name: ARITHMETIC_CIRCUIT_SIZE
          value: "16..25"
        - name: BYTE_PACKING_CIRCUIT_SIZE
          value: "8..25"
        - name: CPU_CIRCUIT_SIZE
          value: "12..27"
        - name: KECCAK_CIRCUIT_SIZE
          value: "14..25"
        - name: KECCAK_SPONGE_CIRCUIT_SIZE
          value: "9..20"
        - name: LOGIC_CIRCUIT_SIZE
          value: "12..25"
        - name: MEMORY_CIRCUIT_SIZE
          value: "17..28"
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
