apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-worker
spec:
  # The number of replicas should be set to zero as it is managed by the HPA.
  replicas: 0
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    nodeSelector: {{ printf "%s:%s" .Values.worker.nodeSelector.key .Values.worker.nodeSelector.value }}
    spec:
      containers:
      - name: worker
        image: {{ .Values.worker.image }}
        command: ["worker"]
        args:
        - "--runtime=amqp"
        env:
        - name: AMQP_URI
          value: {{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace }}
        - name: RUST_LOG
          value: debug
        resources:
          requests:
            memory: {{ .Values.worker.resources.requests.memory }}
            cpu: {{ .Values.worker.resources.requests.cpu }}
          limits:
            memory: {{ .Values.worker.resources.limits.memory }}
            cpu: {{ .Values.worker.resources.limits.cpu }}
