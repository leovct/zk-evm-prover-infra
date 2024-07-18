apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-zk-evm-leader
spec:
  replicas: 1
  selector:
    matchLabels:
      app: leader
  template:
    metadata:
      labels:
        app: leader
    spec:
      containers:
      - name: leader
        image: {{ .Values.zk_evm_image }}
        command: ["leader"]
        args:
        - "--runtime=amqp"
        - "--amqp-uri={{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace }}"
        - "http"
        - "--port={{ .Values.leader.http }}"
        - "--output-dir=/tmp"
        env:
        - name: RUST_BACKTRACE
          value: full
        - name: RUST_LOG
          value: info
        ports:
        - containerPort: {{ .Values.leader.http }}
        # TODO: Remove this after testing.
        securityContext:
          runAsUser: 0

---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-leader-service
spec:
  selector:
    app: leader
  ports:
    - protocol: TCP
      port: {{ .Values.leader.http }}
      targetPort: {{ .Values.leader.http }}
  type: ClusterIP
