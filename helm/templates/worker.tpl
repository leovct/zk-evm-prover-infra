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
    spec:
      containers:
      - name: worker
        image: {{ .Values.worker.image }}
