apiVersion: batch/v1
kind: Job
metadata:
  name: zk-evm-worker-circuits-initializer
  labels:
    release: {{ .Release.Name }}
    app: zk-evm
    component: circuits-initializer
spec:
  template:
    metadata:
      labels:
        app: zk-evm
        component: circuits-initializer
    spec:
      containers:
      - name: circuits-initializer
        image: {{ .Values.jumpbox.image }}
        command: ["/bin/sh", "/scripts/init-circuits.sh"]
        envFrom:
        - configMapRef:
            name: zk-evm-worker-cm
        volumeMounts:
        - name: init-scripts
          mountPath: /scripts
        - name: circuits
          mountPath: /circuits
      restartPolicy: OnFailure
      volumes:
      - name: init-scripts
        configMap:
          name: zk-evm-worker-circuits-initializer-scripts
      - name: circuits
        persistentVolumeClaim:
          claimName: zk-evm-worker-circuits-pvc
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
  name: zk-evm-worker-circuits-initializer-scripts
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
  name: zk-evm-worker-circuits-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
