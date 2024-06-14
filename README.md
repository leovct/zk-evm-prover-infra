# 📦 Polygon Zero Type 1 Prover Helm Chart

A Helm chart to deploy Polygon Zero's [Type 1 Prover](https://github.com/0xPolygonZero/zero-bin) on [Kubernetes](https://kubernetes.io/).

![architecture-diagram](./docs/architecture-diagram.png)

## Usage

To be able to run the type 1 prover infrastructure, you will need:

- A Kubernetes cluster (e.g. [GKE](https://cloud.google.com/kubernetes-engine/docs)).
- Two types of [node pools](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pools):
  - `default-pool`: for standard nodes (e.g. `e2-standard-4`) - with at least 1 node.
  - `highmem-pool`: for high memory nodes (e.g. `c3d-highmen-180` with 1.4Tb of memory) - with at least 2 nodes.

  ![gke-node-pools](./gke-node-pools.png)

- This is still a PoC so you can keep all the nodes in the same availability zone.
- A Blockchain RPC URL, for that you can use [Alchemy](https://dashboard.alchemy.com/apps) for example.
- Note: It would be great to share a terraform project to spin up the GKE infra?
- TODO: You will also need a `jerrigon` node to create the witnesses.

0. Connect to the GKE cluster.

```bash
gcloud auth login
# You might need to run: gcloud components install gke-gcloud-auth-plugin
gcloud container clusters get-credentials type-1-prover-test-01 --zone=europe-west1-c
kubectl get namespaces
```

1. Install the [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq-cluster-operator bitnami/rabbitmq-cluster-operator \
  --version 4.3.6 \
  --namespace rabbitmq-cluster-operator \
  --create-namespace
```

2. Install [KEDA](https://keda.sh/), the Kubernetes Event-Driven Autoscaler containing the [RabbitMQ Queue](https://www.rabbitmq.com/kubernetes/operator/operator-overview) HPA ([Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  --version 2.14.2 \
  --namespace keda \
  --create-namespace
```

To get the latest version of these [Helm](https://helm.sh/) charts, you can use:

```bash
helm search hub rabbitmq-cluster-operator --output yaml | yq '.[] | select(.repository.url == "https://charts.bitnami.com/bitnami")'
helm search hub keda --output yaml | yq '.[] | select(.repository.url == "https://kedacore.github.io/charts")'
```

3. Deploy the [zero-prover](https://github.com/0xPolygonZero/zero-bin) infrastructure in Kubernetes.

```bash
helm install test --namespace zero --create-namespace ./helm
```
