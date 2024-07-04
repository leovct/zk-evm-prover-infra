# 📦 Polygon Zero Type 1 Prover Helm Chart

A Helm chart to deploy Polygon Zero's [Type 1 Prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) on [Kubernetes](https://kubernetes.io/).

![architecture-diagram](./docs/architecture-diagram.png)

## Deploying GKE with Terraform

The below GKE infrastructure requirement can be automated using the provided terraform scripts under `/terraform` directory.

```!
# First authenticate with your GCP account
gcloud auth application-default login

# Check which project is active and switch as necessary under /terraform/variables.tf
gcloud config get-value project

# Once all the deployment variables have been declared under /terraform/variables.tf start the terraform deployment
terraform init

# Check the predicted deployment outputs
terraform plan

# Deploy the infrastructure
terraform apply
```

With the above instructions, you should have a setup which mimics the below requirement:
- A VPC and a subnet
- GKE cluster and a separately managed node pool

## Generating Witnesses using Jerigon

Clone the Jerigon repo and checkout the below commit hash.
```!
git clone git@github.com:0xPolygonZero/erigon.git
git checkout -b 83e0f2fa8c8f6632370e20fef7bbc8a4991c73c8
```

Then build Jerigon, and build it again for Docker
```!
make all
docker build -t erigon:local .
```

Clone the Ethereum Kurtosis repo which we'll use to spin up Jerigon from the built local image.
```!
git clone git@github.com:kurtosis-tech/ethereum-package.git
```

Make sure the `network_params.yml` has been changed as needed:
```!
 participants:
 # EL
-  - el_type: geth
-    el_image: ethereum/client-go:latest
+  - el_type: erigon
+    el_image: erigon:local
...
 additional_services:
-  - tx_spammer
-  - blob_spammer
+  # - tx_spammer
+  # - blob_spammer
```

Then spin up the Jerigon devnet with Kurtosis
```!
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package@4.0.0 --args-file network_params.yml
```
The output should look something like:
![jerigon-kurtosis](./docs/jerigon-kurtosis.png)

To make transactions, refer to the [list](https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star) of funded accounts.

Clone the zk_evm repo and checkout the below commit hash.
```!
git clone git@github.com:0xPolygonZero/zk_evm.git
git checkout -b b7cea483f41dffc5bb3f4951ba998f285bed1f96
```

`cd` into the `zero_bin/rpc` directory and edit the value for `i=<block_number>` and run the below command
```!
i=<block_number>
cargo run --bin rpc fetch --rpc-url $(kurtosis port print my-testnet el-2-erigon-lighthouse ws-rpc) --start-block $i --end-block $i | jq '.'[] > ./witness_$i.json
```

You can also choose to save the block data which would be useful
```!
i=<block_number>
cast block --rpc-url $(kurtosis port print my-testnet el-2-erigon-lighthouse ws-rpc) --json > ./block_$i.json
```

## Usage

To be able to run the type 1 prover infrastructure, you will need:

- A VPC (see [zero-prover-test-vpc](https://console.cloud.google.com/networking/networks/details/zero-prover-test-vpc?project=prj-polygonlabs-devtools-dev&authuser=2&pageTab=OVERVIEW)).
- A Kubernetes cluster (e.g. [GKE](https://cloud.google.com/kubernetes-engine/docs)).
- Two types of [node pools](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pools):
  - `default-pool`: for standard nodes (e.g. `e2-standard-4`) - with at least 1 node and 300Gb of disk.
  - `highmem-pool`: for high memory nodes (e.g. `c3d-highmen-180` with 1.4Tb of memory) - with at least 1 node and 300Gb of disk.

  ![gke-node-pools](./docs/gke-node-pools.png)

  - Make sure that you apply the [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) `highmem=true:NoSchedule` to the `highmem-pool` to only allow worker pods to be scheduled on these nodes.

- This is still a PoC so you can keep all the nodes in the same availability zone.
- A `jerrigon` blockchain RPC URL to create the witnesses.
- TODO: It would be great to share a Terraform project to spin up the GKE infra.

0. Connect to the GKE cluster.

```bash
gcloud auth login
# You might need to run: gcloud components install gke-gcloud-auth-plugin
gcloud container clusters get-credentials zero-prover-test-01 --zone=europe-west1-c
kubectl get namespaces
```

You can now start Lens and monitor the state of the cluster.

![observer-cluster-with-lens](./docs/observer-cluster-with-lens.png)


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

3. Deploy the [zero-prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) infrastructure in Kubernetes.

```bash
helm install test --namespace zero --create-namespace ./helm
```

Your cluster should now be ready!

![cluster-is-ready](./docs/cluster-is-ready.png)

4. Generate a proof! 🥳

Get a running shell inside the `jumpbox` container.

```bash
jumpbox_pod_name="$(kubectl get pods --namespace zero -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep jumpbox)"
kubectl exec --namespace zero --stdin --tty "$jumpbox_pod_name" -- /bin/bash
```

Generate proof using a witness (check `data.tar.gz` for blocks and witnesses files).

```bash
cd /home
curl -L -O https://github.com/leovct/zero-prover-infra/raw/8fdf9108482dd63c9424d5a8a555ef892d262c59/data.tar.gz
tar -xvf data.tar.gz
apt-get install --yes vim
vim /home/data/witness-0001.json
# Copy the content of the witness file...
```

Note that we would like to be able to generate witnesses on the fly but it requires to have a `jerrigon` node.

```bash
env RUST_BACKTRACE=full RUST_LOG=debug leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < /home/data/witness-0001.json &> /home/data/proof-0001.leader.out
```

```bash
2024-06-18T00:56:13.907559Z DEBUG lapin::channels: create channel id=0
2024-06-18T00:56:13.924859Z DEBUG lapin::channels: create channel
2024-06-18T00:56:13.924884Z DEBUG lapin::channels: create channel id=1
2024-06-18T00:56:13.932668Z  INFO prover: Proving block 1
2024-06-18T00:56:43.925763Z DEBUG lapin::channels: received heartbeat from server
2024-06-18T00:56:43.938936Z DEBUG lapin::channels: send heartbeat
2024-06-18T00:57:22.704959Z DEBUG lapin::channels: send heartbeat
2024-06-18T00:57:39.675806Z  INFO prover: Successfully proved block 1
# proof content
```

You can check the content of `/home/data/proof-0001.leader.out` or you can extract the proof and run the `verifier`.

```bash
tail -n1 /home/data/proof-0001.leader.out | jq > /home/data/proof-0001.json
env RUST_LOG=info verifier --file-path /home/data/proof-0001.json
```

The `verifier` fails in this case unfortunately.

```bash
2024-06-18T00:59:59.440487Z  INFO common::prover_state: initializing verifier state...
2024-06-18T00:59:59.440547Z  INFO common::prover_state: attempting to load preprocessed verifier circuit from disk...
2024-06-18T00:59:59.440621Z  INFO common::prover_state: failed to load preprocessed verifier circuit from disk. generating it...
2024-06-18T01:01:50.693251Z  INFO common::prover_state: saving preprocessed verifier circuit to disk
2024-06-18T01:01:52.809270Z  INFO verifier: Proof verification failed with error: ProofGenError("Condition failed: `vanishing_polys_zeta [i] == z_h_zeta * reduce_with_powers (chunk, zeta_pow_deg)`")
```

Note that the `leader` might fail to generate proofs for other types of witnesses. Here is an example.

```bash
env RUST_BACKTRACE=full RUST_LOG=debug leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < /home/data/witness-0034.json
```

```bash
2024-06-18T01:11:36.217473Z DEBUG lapin::channels: create channel id=0
2024-06-18T01:11:36.236822Z DEBUG lapin::channels: create channel
2024-06-18T01:11:36.236842Z DEBUG lapin::channels: create channel id=1
2024-06-18T01:11:36.245752Z  INFO prover: Proving block 34
2024-06-18T01:12:06.237640Z DEBUG lapin::channels: received heartbeat from server
2024-06-18T01:12:06.252661Z DEBUG lapin::channels: send heartbeat
2024-06-18T01:12:46.964363Z DEBUG lapin::channels: send heartbeat
Error: Fatal operation error: "Inconsistent pre-state for first block 0x27d9465f649ad19e7e399a0116be7a0ad9225b44d09455c6e2dfa23487a0fb48 with checkpoint state 0x2dab6a1d6d638955507777aecea699e6728825524facbd446bd4e86d44fa5ecd."

Stack backtrace:
   0: anyhow::kind::Adhoc::new
   1: <futures_util::stream::stream::map::Map<St,F> as futures_core::stream::Stream>::poll_next
   2: paladin::directive::literal::functor::<impl paladin::directive::Functor<B> for paladin::directive::literal::Literal<A>>::f_map::{{closure}}
   3: <paladin::directive::Map<Op,D> as paladin::directive::Directive>::run::{{closure}}
   4: prover::BlockProverInput::prove::{{closure}}
   5: leader::main::{{closure}}
   6: leader::main
   7: std::sys_common::backtrace::__rust_begin_short_backtrace
   8: main
   9: __libc_start_main
  10: _start
```

## TODOs / Known Issues

- [ ] The leader communicates with the pool of worker through RabbitMQ by creating a queue by proof request. However, [RabbitMQ Queue](https://keda.sh/docs/2.14/scalers/rabbitmq-queue/) can only scale the number of workers based on the size of the message backlog (for a specific queue), or the publish/sec rate. There is no way to scale the number of workers based on the total message backlog across all queues? I asked the [question](https://kubernetes.slack.com/archives/CKZJ36A5D/p1718671628824279) in the Kubernetes Slack.

  => I started to work on that in `helm/templates/rabbitmq-hpa.tpl`.

- [ ] Collect metrics using `atop` while proving blocks.

- [ ] The setup does not use any `jerrigon` node to generate the witnesses, instead, we provide the witnesses directly to the leader. This should be changed, especially because we would like to be able to follow the tip of the chain. We would then need to detect the new block (and probably introduce some kind of safety mechanism to make sure the block won't get reorged), generate a witness for the block and prove the block using the witness.

- [ ] Provide at the very least `gcloud` commands to create the GKE cluster or a terraform project.
