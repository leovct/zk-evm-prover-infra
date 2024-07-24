apiVersion: apps/v1
kind: Deployment
metadata:
  name: zk-evm-jumpbox
  labels:
    release: {{ .Release.Name }}
    app: zk-evm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zk-evm
  template:
    metadata:
      labels:
        app: zk-evm
    spec:
      containers:
      - name: jumpbox
        image: {{ .Values.jumpbox.image }}
        command: [ "sleep" ]
        args: [ "infinity" ]
