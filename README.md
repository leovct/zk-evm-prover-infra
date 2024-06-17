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
gcloud container clusters get-credentials zero-prover-test-01 --zone=europe-west1-c
kubectl get namespaces
```

You can now start Lens and monitor the state of the cluster.

![observer-cluster-with-lens](./observer-cluster-with-lens.png)


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

Your cluster should now be ready!

![cluster-is-ready](./cluster-is-ready.png)

4. Generate a proof! 🥳

Get a running shell inside the `jumpbox` container.

```bash
jumpbox_pod_name="$(kubectl get pods --namespace zero -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep jumpbox)"
kubectl exec --namespace zero --stdin --tty "$jumpbox_pod_name" -- /bin/bash
```

Generate a proof using a witness previously saved at `witness.json` (check `data/`).

```bash
apt-get install --yes vim
vim /home/witness-0034.json
# copy the content of the witness file
```

Note that we would like to be able to generate witnesses on the fly but it requires to have a `jerrigon` node.

```bash
cd /usr/local/bin
export ARITHMETIC_CIRCUIT_SIZE="16..21"
export BYTE_PACKING_CIRCUIT_SIZE="9..21"
export CPU_CIRCUIT_SIZE="12..23"
export KECCAK_CIRCUIT_SIZE="14..19"
export KECCAK_SPONGE_CIRCUIT_SIZE="9..15"
export LOGIC_CIRCUIT_SIZE="12..18"
export MEMORY_CIRCUIT_SIZE="17..25"
env RUST_BACKTRACE=full RUST_LOG=debug leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < /home/witness-0034.json
```

For the moment, we get an error...

![leader-issue](./leader-issue.png)

```bash
root@test-jumpbox-7779b5dd7d-shrxz:/# env RUST_BACKTRACE=full RUST_LOG=debug leader   --runtime=amqp   --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672   stdio < /home/witness-0034.json
2024-06-17T10:02:29.607786Z DEBUG lapin::channels: create channel id=0
2024-06-17T10:02:29.624745Z DEBUG lapin::channels: create channel
2024-06-17T10:02:29.624767Z DEBUG lapin::channels: create channel id=1
2024-06-17T10:02:29.633851Z ERROR lapin::io_loop: error doing IO error=IOError(Custom { kind: Other, error: "A Tokio 1.x context was found, but it is being shutdown." })
2024-06-17T10:02:29.633914Z ERROR lapin::channels: Connection error error=IO error: A Tokio 1.x context was found, but it is being shutdown.
Error: invalid type: map, expected a sequence at line 1 column 0

Stack backtrace:
   0: anyhow::error::<impl core::convert::From<E> for anyhow::Error>::from
   1: leader::main::{{closure}}
   2: leader::main
   3: std::sys_common::backtrace::__rust_begin_short_backtrace
   4: main
   5: __libc_start_main
   6: _start
```

Check that the witness is a correct JSON file.

```bash
jq . /home/witness-0034.json
```

Check that the `jumpbox` can connect to the RabbitMQ cluster. These are the logs from the `test-rabbitmq-cluster-server-0` pod. The connection is being established but the client closes it instantly.

```bash
2024-06-17 10:02:15.679340+00:00 [info] <0.2444.0> accepting AMQP connection <0.2444.0> (10.124.0.10:58642 -> 10.124.1.11:5672)
2024-06-17 10:02:15.680833+00:00 [info] <0.2444.0> connection <0.2444.0> (10.124.0.10:58642 -> 10.124.1.11:5672): user 'guest' authenticated and granted access to vhost '/'
2024-06-17 10:02:15.689512+00:00 [warning] <0.2444.0> closing AMQP connection <0.2444.0> (10.124.0.10:58642 -> 10.124.1.11:5672, vhost: '/', user: 'guest'):
2024-06-17 10:02:15.689512+00:00 [warning] <0.2444.0> client unexpectedly closed TCP connection
```
