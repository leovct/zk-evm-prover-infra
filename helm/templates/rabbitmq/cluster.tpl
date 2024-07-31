# Define a RabbitMQ cluster that will be managed by the RabbitMQ Cluster Operator.
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rabbitmq-cluster
  labels:
    release: {{ .Release.Name }}
    app: rabbitmq
  annotations:
    # The RabbitmqCluster CR will be deployed after all resources are loaded into Kubernetes.
    # This prevent an issue where the RabbitmqCluster CR is installed before the CRD.
    "helm.sh/hook": post-install
spec:
  # The image to use.
  image: {{ .Values.rabbitmq.cluster.image }}
  # The number of RabbitMQ nodes.
  replicas: {{ .Values.rabbitmq.cluster.nodeCount }}
  # Additional RabbitMQ configuration.
  rabbitmq:
    # Config added to rabbitmq.conf in addition to the default configurations set by the operator.
    additionalConfig: |
      default_user = {{ .Values.rabbitmq.cluster.credentials.username }}
      default_pass = {{ .Values.rabbitmq.cluster.credentials.password }}

---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rabbitmq-cluster
  namespace: kube-prometheus
  labels:
    release: {{ .Release.Name }}
    app: rabbitmq
spec:
  endpoints:
    - port: prometheus
      path: /metrics
      scheme: http
      scrapeTimeout: 15s
  jobLabel: rabbitmq-cluster
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
  selector:
    matchLabels:
      app.kubernetes.io/component: rabbitmq
      app.kubernetes.io/name: rabbitmq-cluster
      app.kubernetes.io/part-of: rabbitmq
      release: prometheus-operator # Mandatory to get scraped by Prometheus
