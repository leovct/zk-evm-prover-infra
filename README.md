# Zero-bin Helm Chart

An Helm chart to run Polygon's [Type 1 Prover](https://github.com/0xPolygonZero/zero-bin) on [Kubernetes](https://kubernetes.io/).

## Usage

Install the [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq-cluster-operator bitnami/rabbitmq-cluster-operator \
  --version 4.3.6 \
  --namespace rabbitmq-cluster-operator \
  --create-namespace
```

Install [KEDA](https://keda.sh/), the Kubernetes Event-Driven Autoscaler containing the [RabbitMQ Queue](https://www.rabbitmq.com/kubernetes/operator/operator-overview) HPA ([Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  --version 2.14.2 \
  --namespace keda \
  --create-namespace
```

To get the latest version of these helm charts, you can use:

```bash
helm search repo bitnami/rabbitmq-cluster-operator
helm search repo kedacore/keda
```

Deploy the [zero-prover](https://github.com/0xPolygonZero/zero-bin) infrastructure in Kubernetes.

```bash
helm install test --namespace zero --create-namespace ./helm
```
