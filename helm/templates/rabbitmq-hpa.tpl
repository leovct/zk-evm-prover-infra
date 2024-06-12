# Define the secret containing the AMQP URL.
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-keda-rabbitmq-secret
data:
  # The AMQP URL should be encoded using base64.
  # TODO: Implement a more robust secret management system to enhance security.
  AMQP_URL: {{ printf "amqp://%s:%s@%s-rabbitmq-cluster.%s.svc.cluster.local:5672" .Values.rabbitmq.cluster.username .Values.rabbitmq.cluster.password .Release.Name .Release.Namespace | b64enc }}

---
# Describe which secret the ScaledObject will use.
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: {{ .Release.Name }}-keda-trigger-auth-rabbitmq-conn
  annotations:
    # The RabbitmqCluster CR will be deployed after all resources are loaded into Kubernetes.
    # This prevent an issue where the RabbitmqCluster CR is installed before the CRD.
    "helm.sh/hook": post-install
    # Deploy the TriggerAuthentication resource after the CRDs have been deployed.
    "helm.sh/hook-weight": "1"
spec:
  secretTargetRef:
    - # The parameter is defined by the scale trigger.
      parameter: host
      # The name of the secret resource.
      # It should be in the same namespace as the ScaledObject.
      name: {{ .Release.Name }}-keda-rabbitmq-secret
      # The name of the key that contains the AMQP URL.
      key: AMQP_URL

---
# Define which resource the HPA will scale and how it will scale it.
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ .Release.Name }}-rabbitmq-scaledobject
  annotations:
    # The RabbitmqCluster CR will be deployed after all resources are loaded into Kubernetes.
    # This prevent an issue where the RabbitmqCluster CR is installed before the CRD.
    "helm.sh/hook": post-install
    # Deploy the ScaledObject resource after the TriggerAuthentication resource.
    "helm.sh/hook-weight": "2"
spec:
  # The resource targeted by the HPA.
  scaleTargetRef:
    # The type of resource to scale.
    apiVersion: apps/v1
    kind: Deployment
    # The name of the application to scale.
    # It must be in the same namespace as the ScaledObject.
    name: {{ .Release.Name }}-worker

  # The minimum number of replicas KEDA will scale the resource down to.
  # By default, it’s scale to zero, but you can use it with some other value as well.
  minReplicaCount: {{ .Values.worker.minWorkerCount }}

  # This setting is passed to the HPA definition that KEDA will create for a given resource and
  # holds the maximum number of replicas of the target resource.
  maxReplicaCount: {{ .Values.worker.maxWorkerCount }}

  # The interval to check each trigger on. In a queue scenario, KEDA will check the `queueLength`
  # every `pollingInterval`, and scale the deployment up or down accordingly.
  pollingInterval: {{ .Values.rabbitmq.hpa.pollingInterval }}

  # HPA configuration.
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        # HPA's scale down behavior.
        scaleDown:
          # The stabilization window is used to restrict the flapping of replica count when the
          # metrics used for scaling keep fluctuating.
          # https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#flapping
          # By default, the scale down stabilization window is set to 300 seconds.
          stabilizationWindowSeconds: 10
          policies:
          # This policy allows 100% of the currently running replicas to be removed which means the
          # scaling target can be scaled down to the minimum allowed replicas. The HPA has 15
          # seconds to reach its steady state.
          # https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#default-behavior
          - type: Percent
            value: 100
            periodSeconds: 15

        # HPA's scale up behavior.
        scaleUp:
          # The stabilization window is used to restrict the flapping of replica count when the
          # metrics used for scaling keep fluctuating.
          # https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#flapping
          # By default, the scale up stabilization window is set to 0 seconds.
          stabilizationWindowSeconds: 0
          policies:
          # These two policies allow 4 pods or a 100% of the currently running replicas to be added
          # every 15 seconds till the HPA reaches its steady state.
          # https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#default-behavior
          - type: Percent
            value: 100
            periodSeconds: 15
          - type: Pods
            value: 4
            periodSeconds: 15
          selectPolicy: Max

  # The list of triggers to activate scaling of the target resource.
  triggers:
  - type: rabbitmq
    metadata:
      # The protocol to be used for communication.
      protocol: amqp
      # The name of the RabbitMQ queue.
      queueName: {{ .Values.rabbitmq.hpa.queue }}
      # The trigger mode. We chose to trigger on number of messages in the queue.
      mode: QueueLength
      # The message backlog to trigger on.
      # It must be a string.
      value: "20"
    authenticationRef:
      # The name of the TriggerAuthentication object.
      name: {{ .Release.Name }}-keda-trigger-auth-rabbitmq-conn
