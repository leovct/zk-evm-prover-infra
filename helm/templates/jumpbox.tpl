apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-jumpbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jumpbox
  template:
    metadata:
      labels:
        app: jumpbox
    spec:
      containers:
      - name: jumpbox
        image: {{ .Values.jumpbox.image }}
        imagePullPolicy: Always
        command: [ "sleep" ]
        args: [ "infinity" ]
