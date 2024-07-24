apiVersion: apps/v1
kind: Deployment
metadata:
  name: zk-evm-jumpbox
  labels:
    release: {{ .Release.Name }}
    app: zk-evm
    component: jumpbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zk-evm
      component: jumpbox
  template:
    metadata:
      labels:
        app: zk-evm
        component: jumpbox
    spec:
      containers:
      - name: jumpbox
        image: {{ .Values.jumpbox.image }}
        command: [ "sleep" ]
        args: [ "infinity" ]
