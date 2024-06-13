# Define a RabbitMQ cluster that will be managed by the RabbitMQ Cluster Operator.
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: {{ .Release.Name }}-rabbitmq-cluster
  annotations:
    # The RabbitmqCluster CR will be deployed after all resources are loaded into Kubernetes.
    # This prevent an issue where the RabbitmqCluster CR is installed before the CRD.
    "helm.sh/hook": post-install
spec:
  # The image to use.
  image: {{ .Values.rabbitmq.cluster.image }}
  # The number of RabbitMQ nodes.
  replicas: {{ .Values.rabbitmq.cluster.nodeCount }}
  nodeSelector: {{ printf "%s:%s" .Values.rabbitmq.cluster.nodeSelector.key .Values.rabbitmq.cluster.nodeSelector.value }}
  # Additional RabbitMQ configuration.
  rabbitmq:
    # Config added to rabbitmq.conf in addition to the default configurations set by the operator.
    additionalConfig: |
      default_user = {{ .Values.rabbitmq.cluster.username }}
      default_pass = {{ .Values.rabbitmq.cluster.password }}
