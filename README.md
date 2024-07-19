# 📦 Polygon Zero Type 1 Prover Infrastructure

Deploy [Polygon Zero's Type 1 Prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) on [Kubernetes](https://kubernetes.io/) using our [Terraform](https://www.terraform.io/) script and [Helm](https://helm.sh/) chart.

## Table of Contents

- [Architecture Diagram](#architecture-diagram)
- [Setup](#setup)
  - [GKE Cluster](#gke-cluster)
  - [zkEVM Prover Infrastructure](#zkevm-prover-infrastructure)
  - [Docker Images](#docker-images)
- [Monitoring](#monitoring)
- [Block Proving](#block-proving)
  - [Witness Generation](#witness-generation)
  - [Proof Generation](#proof-generation)
- [TODOs](#todos)

## Architecture Diagram

![architecture-diagram](./docs/architecture-diagram.png)

## Setup

### GKE Cluster

The above [GKE](https://cloud.google.com/kubernetes-engine) infrastructure can be deployed using the provided [Terraform](https://www.terraform.io/) scripts under the `terraform` directory.

First, authenticate with your [GCP](https://console.cloud.google.com/) account.

```bash
gcloud auth application-default login
```

Before deploying anything, check which project is used. The resources will be deployed inside this specific project.

```bash
gcloud config get-value project
```

Next, review the `terraform/variables.tf` file and adjust the infrastructure settings to meet your requirements.

Once you're done, initialize the project to download dependencies and deploy the infrastructure. You can use `terraform plan` to check what kind of resources are going to be deployed.

```bash
pushd terraform
terraform init
terraform apply
popd
```

It takes around 10 minutes for the infrastructure to be deployed and fully operational.

```bash
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

kubernetes_cluster_name = "leovct-test-01-gke-cluster"
kubernetes_version = "1.29.6-gke.1038001"
project_id = "my-gcp-project"
region = "europe-west3"
zones = tolist([
  "europe-west3-b",
])
```

With the above instructions, you should have a setup that mimics the below requirements:

- A VPC and a subnet
- GKE cluster with two node pools

Note that it may take some time for the Kubernetes cluster to be ready on GCP!

![gke-cluster](docs/gke-cluster.png)

### zkEVM Prover Infrastructure

First, authenticate with your [GCP](https://console.cloud.google.com/) account.

```bash
gcloud auth login
```

Get access to the GKE cluster config.

```bash
# gcloud container clusters get-credentials <gke-cluster-name> --region=<region>
gcloud container clusters get-credentials my-gke-cluster --region=europe-west3
```

Make sure you have access to the GKE cluster you just created. It should list the nodes of the cluster.

```bash
kubectl get nodes
```

You can now start to use [Lens](https://k8slens.dev/) to visualize and control the Kubernetes cluster.

![lens-overview](docs/lens-overview.png)

Now, let's deploy the zero infrastructure in GKE.

First, install the [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq-cluster-operator bitnami/rabbitmq-cluster-operator \
  --version 4.3.14 \
  --namespace rabbitmq-cluster-operator \
  --create-namespace
```

Then, install [KEDA](https://keda.sh/), the Kubernetes Event-Driven Autoscaler containing the [RabbitMQ Queue](https://www.rabbitmq.com/kubernetes/operator/operator-overview) HPA ([Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  --version 2.14.2 \
  --namespace keda \
  --create-namespace
```

Finally, install [Prometheus Operator](https://prometheus-operator.dev/).

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --version 61.3.1 \
  --namespace kube-prometheus \
  --create-namespace
```

These commands could have been written a while ago so make sure you use "recent" versions.

```bash
helm search hub rabbitmq-cluster-operator --output yaml | yq '.[] | select(.repository.url == "https://charts.bitnami.com/bitnami")'
helm search hub keda --output yaml | yq '.[] | select(.repository.url == "https://kedacore.github.io/charts")'
helm search hub kube-prometheus-stack --output yaml | yq '.[] | select(.repository.url == "https://prometheus-community.github.io/helm-charts")'
```

Finally, deploy the [zero-prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) infrastructure in Kubernetes.

```bash
helm install test --namespace zero --create-namespace ./helm
```

Your cluster should now be ready to prove blocks!

![cluster-ready](./docs/cluster-ready.png)

### Docker Images

Provision an Ubuntu/Debian VM with good specs (e.g. `t2d-60`).

Switch to admin.

```bash
sudo su
```

Install docker.

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" |tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
docker run hello-world
```

#### Build Zk-EVM Image

Install dependencies.

```bash
apt-get update
apt-get install --yes build-essential git libjemalloc-dev libjemalloc2 make libssl-dev pkg-config
```

Install rust.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"
rustup toolchain install nightly
rustup default nightly
```

Clone `0xPolygonZero/zk_evm`.

```bash
mkdir /opt/zk_evm
git clone https://github.com/0xPolygonZero/zk_evm.git /opt/zk_evm
```

Build the `zk_evm` binaries and docker images.

```bash
pushd /opt/zk_evm

git checkout v0.5.0
env RUSTFLAGS='-C target-cpu=native -Zlinker-features=-lld' cargo build --release
docker build --tag leovct/zk_evm:v0.5.0 .

git checkout v0.6.0
env RUSTFLAGS='-C target-cpu=native -Zlinker-features=-lld' cargo build --release
docker build --tag leovct/zk_evm:v0.6.0 .
```

Push the images.

```bash
docker login
docker push leovct/zk_evm:v0.5.0
docker push leovct/zk_evm:v0.6.0
```

Images are hosted on [Docker Hub](https://hub.docker.com/repository/docker/leovct/zk_evm/general) for the moment.

#### Build Jumpbox Image

Clone `leovct/zero-prover-infra`.

```bash
mkdir /opt/zero-prover-infra
git clone https://github.com/leovct/zero-prover-infra /opt/zero-prover-infra
```

Build the jumpbox images.

```bash
pushd /opt/zero-prover-infra/docker
docker build --tag leovct/zero-jumpbox:v0.5.0 --build-arg ZERO_BIN_BRANCH_OR_COMMIT=v0.5.0 --file jumpbox.Dockerfile .
docker build --tag leovct/zero-jumpbox:v0.6.0 --build-arg ZERO_BIN_BRANCH_OR_COMMIT=v0.6.0 --file jumpbox.Dockerfile .
```

Check that the images are built correctly.

```bash
docker run --rm -it leovct/zero-jumpbox:v0.5.0 /bin/bash
rpc --help
worker --help
leader --help
verifier --help
```

Push the images.

```bash
docker login
docker push leovct/zero-jumpbox:v0.5.0
docker push leovct/zero-jumpbox:v0.6.0
```

Images are hosted on [Docker Hub](https://hub.docker.com/repository/docker/leovct/zero-jumpbox/general) for the moment.

## Monitoring

You can observe cluster metrics using [Grafana](https://grafana.com/). To access it, execute two separate commands in different terminal sessions. When prompted for login information, enter `admin` as the username and `prom-operator` as the password.

```bash
kubectl port-forward --namespace kube-prometheus --address localhost service/prometheus-operator-grafana 3000:http-web
open http://localhost:3000/
```

![cluster-metrics](./docs/cluster-metrics.png)

Add this handy [dashboard](https://grafana.com/grafana/dashboards/10991-rabbitmq-overview/) to monitor the state of the RabbitMQ Cluster. You can import the dashboard by specifying the dashboard ID `10991`.

![rabbitmq-metrics](./docs/rabbitmq-metrics.png)

It's also possible to access Prometheus web interface.

```bash
kubectl port-forward --namespace kube-prometheus --address localhost service/prometheus-operated 9090:http-web
open http://localhost:9090/
```

![prometheus-ui](./docs/prometheus-ui.png)

Finally, you can log into the RabbitMQ management interface using `guest` credentials as username and password.

```bash
kubectl port-forward --namespace zero --address localhost service/test-rabbitmq-cluster 15672:management
open http://localhost:15672/
```

![rabbitmq-ui](./docs/rabbitmq-ui.png)

Here are some useful links to monitor state of the cluster once ports have been forwarded:

- [Grafana Dashboard to Monitor Kubernetes Cluster Metrics](http://localhost:3000/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?orgId=1&refresh=10s&var-datasource=default&var-cluster=&var-namespace=zero)
- [Grafana Dashboard to Monitor RabbitMQ Metrics](http://localhost:3000/d/Kn5xm-gZk/rabbitmq-overview?orgId=1&refresh=15s)
- [RabbitMQ Management UI](http://localhost:15672/#/queues)
- [Prometheus Web UI](http://localhost:9090/graph?g0.expr=kube_pod_container_status_restarts_total%7Bpod%3D~%22.*zk-evm-worker.*%22%7D&g0.tab=1&g0.display_mode=lines&g0.show_exemplars=0&g0.range_input=1h)

If you ever need to update the stack, you can use the following command.

```bash
helm upgrade test --namespace zero --create-namespace ./helm
```

## Block Proving

### Witness Generation

[Jerrigon](https://github.com/0xPolygonZero/erigon/tree/feat/zero) is a fork of [Erigon](https://github.com/ledgerwatch/erigon) that allows seamless integration of [Polygon Zero's Type 1 Prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin), facilitating the generation of witnesses and the proving of blocks using zero-knowledge proofs.

First, clone the Jerigon repository and check out the below commit hash.

```bash
git clone git@github.com:0xPolygonZero/erigon.git
pushd erigon
git checkout 83e0f2fa8c8f6632370e20fef7bbc8a4991c73c8
```

Then, build the binary and the docker image.

```bash
make all
docker build --tag erigon:local .
```

In the meantime, clone the [Ethereum / Kurtosis](https://github.com/ethpandaops/ethereum-package) repository.

```bash
git clone git@github.com:kurtosis-tech/ethereum-package.git
pushd ethereum-package
```

Adjust the `network_params.yml` file to replace the `geth` execution client by `jerrigon`. Also, disable some of the additional services.

```diff
diff --git a/network_params.yaml b/network_params.yaml
index 77b25f7..9044280 100644
--- a/network_params.yaml
+++ b/network_params.yaml
@@ -1,7 +1,7 @@
 participants:
 # EL
-  - el_type: geth
-    el_image: ethereum/client-go:latest
+  - el_type: erigon
+    el_image: erigon:local
     el_log_level: ""
     el_extra_env_vars: {}
     el_extra_labels: {}
```

Then, spin up a local L1 devnet using [Kurtosis](https://www.kurtosis.com/).

```bash
kurtosis run --enclave my-testnet --args-file network_params.yaml .
```

It should deploy two validator nodes using `jerrigon` as the execution client.

```bash
kurtosis enclave inspect my-testnet
```

```bash
Name:            my-testnet
UUID:            520bab80b8cc
Status:          RUNNING
Creation Time:   Thu, 11 Jul 2024 12:06:53 CEST
Flags:

========================================= Files Artifacts =========================================
UUID           Name
ea91ccbfe06e   1-lighthouse-erigon-0-63-0
640f867340cc   2-lighthouse-erigon-64-127-0
89b481d6aef8   el_cl_genesis_data
d40b6d404f10   final-genesis-timestamp
6639aa45c61c   genesis-el-cl-env-file
f0ac99a6241f   genesis_validators_root
b3a7ac4b3303   jwt_file
3f78b4040032   keymanager_file
9c738ed50303   prysm-password
8e7b75ac4c19   validator-ranges

========================================== User Services ==========================================
UUID           Name                                             Ports                                         Status
9d54c060960c   cl-1-lighthouse-erigon                           http: 4000/tcp -> http://127.0.0.1:51940      RUNNING
                                                                metrics: 5054/tcp -> http://127.0.0.1:51941
                                                                tcp-discovery: 9000/tcp -> 127.0.0.1:51942
                                                                udp-discovery: 9000/udp -> 127.0.0.1:49183
6ef0845c55bc   cl-2-lighthouse-erigon                           http: 4000/tcp -> http://127.0.0.1:52074      RUNNING
                                                                metrics: 5054/tcp -> http://127.0.0.1:52075
                                                                tcp-discovery: 9000/tcp -> 127.0.0.1:52076
                                                                udp-discovery: 9000/udp -> 127.0.0.1:55230
4a036788f6d1   el-1-erigon-lighthouse                           engine-rpc: 8551/tcp -> 127.0.0.1:51757       RUNNING
                                                                metrics: 9001/tcp -> http://127.0.0.1:51758
                                                                tcp-discovery: 30303/tcp -> 127.0.0.1:51755
                                                                udp-discovery: 30303/udp -> 127.0.0.1:61732
                                                                ws-rpc: 8545/tcp -> 127.0.0.1:51756
160ff02c83c8   el-2-erigon-lighthouse                           engine-rpc: 8551/tcp -> 127.0.0.1:51769       RUNNING
                                                                metrics: 9001/tcp -> http://127.0.0.1:51767
                                                                tcp-discovery: 30303/tcp -> 127.0.0.1:51770
                                                                udp-discovery: 30303/udp -> 127.0.0.1:59846
                                                                ws-rpc: 8545/tcp -> 127.0.0.1:51768
a85aed519db4   validator-key-generation-cl-validator-keystore   <none>                                        RUNNING
d4e829923bc9   vc-1-erigon-lighthouse                           metrics: 8080/tcp -> http://127.0.0.1:52144   RUNNING
8bdec2ae9d9b   vc-2-erigon-lighthouse                           metrics: 8080/tcp -> http://127.0.0.1:52174   RUNNING
```

Refer to the list of [pre-funded accounts](https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star#L9) to send transactions to the network.

Clone the [zk_evm](https://github.com/0xPolygonZero/zk_evm) repository and check out the below commit hash.

```bash
git clone git@github.com:0xPolygonZero/zk_evm.git
pushd zk_evm
git checkout b7cea483f41dffc5bb3f4951ba998f285bed1f96
```

You are now ready to generate witnesses for any block of the L1 local chain using the zero prover.

To get the last block number, you can use the following command using [cast](https://book.getfoundry.sh/cast/).

```bash
cast block-number --rpc-url $(kurtosis port print my-testnet el-1-erigon-lighthouse ws-rpc)
```

Generate the witness of the last block number.

```bash
pushd zero_bin/rpc
i="$(cast block-number --rpc-url $(kurtosis port print my-testnet el-1-erigon-lighthouse ws-rpc))"
cargo run --bin rpc fetch --rpc-url "http://$(kurtosis port print my-testnet el-1-erigon-lighthouse ws-rpc)" --start-block "$i" --end-block "$i" | jq '.[]' > "witness_$i.json"
```

You can check the generated witness.

```bash
jq . "witness_$i.json"
```

You can also choose to save the block data which would be useful.

```bash
cast block --rpc-url "$(kurtosis port print my-testnet el-1-erigon-lighthouse ws-rpc)" --json | jq > "block_$i.json"
```

You can check the block data.

```bash
jq . "block_$i.json"
```

### Proof Generation

Get a running shell inside the `jumpbox` container.

```bash
jumpbox_pod_name="$(kubectl get pods --namespace zero -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep jumpbox)"
kubectl exec --namespace zero --stdin --tty "$jumpbox_pod_name" -- /bin/bash
```

Download an archive full of witnesses.

```bash
curl -L --output /tmp/witnesses.xz https://cf-ipfs.com/ipfs/QmTk9TyuFwA7rjPh1u89oEp8shpFUtcdXuKRRySZBfH1Pu
mkdir -p /tmp/witnesses
tar --extract --file=/tmp/witnesses.xz --directory=/tmp/witnesses --strip-components=1 --checkpoint=10000 --checkpoint-action=dot
```

> Note that we would like to be able to generate witnesses on the fly but it requires to have a `jerrigon` node! We will skip this part for the moment.

For example, we will attempt to prove the first witness of the archive, `20241038.witness.json`.

```bash
witness_file="/tmp/witnesses/20241038.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

You can check the content of `/tmp/witnesses/20241038.witness.json.leader.out` or you can extract the proof and run the `verifier`.

```bash
tail -n1 /tmp/witnesses/20241038.witness.json.leader.out | jq > /tmp/witnesses/20241038.proof.json
env RUST_LOG=info verifier --file-path /tmp/witnesses/20241038.proof.json
```

## TODOs

- [ ] The leader communicates with the pool of workers through RabbitMQ by creating a queue by proof request. However, [RabbitMQ Queue](https://keda.sh/docs/2.14/scalers/rabbitmq-queue/) can only scale the number of workers based on the size of the message backlog (for a specific queue), or the publish/sec rate. There is no way to scale the number of workers based on the total message backlog across all queues? I asked the [question](https://kubernetes.slack.com/archives/CKZJ36A5D/p1718671628824279) in the Kubernetes Slack.

  => I started to work on that in `helm/templates/rabbitmq-hpa.tpl`.

- [ ] Collect metrics using `atop` while proving blocks.

- [ ] The setup does not use any `jerrigon` node to generate the witnesses, instead, we provide the witnesses directly to the leader. This should be changed, especially because we would like to be able to follow the tip of the chain. We would then need to detect the new block (and probably introduce some kind of safety mechanism to make sure the block won't get reorged), generate a witness for the block and prove the block using the witness.

- [ ] Provide at the very least `gcloud` commands to create the GKE cluster or a terraform project.
