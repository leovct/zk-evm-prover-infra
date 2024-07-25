# 📦 Polygon's Zk EVM Type 1 Prover Infrastructure

Deploy [Polygon's Zk EVM Type 1 Prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) on [Kubernetes](https://kubernetes.io/) using our [Terraform](https://www.terraform.io/) script and [Helm](https://helm.sh/) chart.

## Table of Contents

- [Architecture Diagram](#architecture-diagram)
- [Prover Infrastructure Setup](#prover-infrastructure-setup)
- [Proving Blocks](#proving-blocks)
- [Feedback](#feedback)
- [Next Steps](#next-steps)

## Architecture Diagram

![architecture-diagram](./docs/architecture-diagram-v2.png)

## Prover Infrastructure Setup

You have two options to set up the infrastructure: follow the step-by-step procedure outlined below, or use the provided script for a streamlined setup. The script automates the entire process, creating the GKE infrastructure with Terraform and deploying all necessary Kubernetes resources, including RabbitMQ, KEDA, Prometheus, and the zk_evm prover infrastructure.

### One-Line Getting Started Command

```bash
./tools/setup.sh
```

### GKE Cluster

<details>
<summary>Click to expand</summary>

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

Deploying the GKE cluster is the main bottleneck while provisioning.

```bash
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs (sample):

kubernetes_cluster_name = "leovct-test-01-gke-cluster"
kubernetes_version = "1.29.6-gke.1038001"
project_id = "my-gcp-project"
region = "europe-west3"
zones = tolist([
  "europe-west3-b",
])
```

With the above instructions, you should have a topology like the following:

- A VPC and a subnet
- GKE cluster with two node pools

![gke-cluster](docs/gke-cluster.png)

</details>

### Zk EVM Prover Infrastructure

<details>
<summary>Click to expand</summary>

First, authenticate with your [GCP](https://console.cloud.google.com/) account.

Note: the authenticated user is no longer 'application-default', which was only required for provisioning our GKE cluster at the terraform stage.

```bash
gcloud auth login
```

Get access to the GKE cluster config.

Adjust your cluster name accordingly.

```bash
# gcloud container clusters get-credentials <gke-cluster-name> --region=<region>
gcloud container clusters get-credentials leovct-test-01-gke-cluster --region=europe-west3
```

Make sure you have access to the GKE cluster you just created. It should list the nodes of the cluster.

```bash
kubectl get nodes
```

You should see at least two nodes. There may be more if you have updated the terraform configuration.

```bash
NAME                                                  STATUS   ROLES    AGE     VERSION
gke-leovct-test-01-g-default-node-poo-9faa7f06-b0q6   Ready    <none>   10m     v1.29.6-gke.1038001
gke-leovct-test-01-g-highmem-node-poo-c5b7d8d5-ms62   Ready    <none>   8m12s   v1.29.6-gke.1038001
```

You can now start to use [Lens](https://k8slens.dev/) to visualize and control the Kubernetes cluster.

![lens-overview](docs/lens-overview.png)

#### RabbitMQ Operator

First, install the [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq-cluster-operator bitnami/rabbitmq-cluster-operator \
  --version 4.3.14 \
  --namespace rabbitmq-cluster-operator \
  --create-namespace
```

#### KEDA Operator

Then, install [KEDA](https://keda.sh/), the Kubernetes Event-Driven Autoscaler containing the [RabbitMQ Queue](https://www.rabbitmq.com/kubernetes/operator/operator-overview) HPA ([Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)).

This component is not needed if you don't want to use the worker autoscaler.

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  --version 2.14.2 \
  --namespace keda \
  --create-namespace
```

#### Prometheus Operator

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

#### Zk EVM Prover

Finally, deploy the [zk_evm prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin) infrastructure in Kubernetes.

```bash
helm install test --namespace zk-evm --create-namespace ./helm
```

It should take a few minutes for the worker pods to be ready. This is because a job called `test-init-circuits` will first start and generate all the zk circuits needed by the workers. Meanwhile, the worker pods do not start, they wait for the circuits to be generated. Once the task has finished and the job has succeeded, the worker pods finally start and load the circuits.

Your cluster should now be ready to prove blocks!

![cluster-ready](./docs/cluster-ready.png)

#### Perform update on Zk EVM Prover stack

If you ever need to update the stack, you can use the following command.

```bash
helm upgrade test --namespace zk-evm --create-namespace ./helm
```

</details>

### Monitoring

<details>
<summary>Click to expand</summary>

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
kubectl port-forward --namespace zk-evm --address localhost service/test-rabbitmq-cluster 15672:management
open http://localhost:15672/
```

![rabbitmq-ui](./docs/rabbitmq-ui.png)

</details>

### Custom Docker Images

<details>
<summary>Click to expand</summary>

Provision an Ubuntu/Debian VM with good specs (e.g. `t2d-standard-60`).

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

#### Build Zk EVM Image

This image contains the zk_evm binaries `leader`, `worker`, `rpc` and `verifier`

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

git checkout v0.6.0
env RUSTFLAGS='-C target-cpu=native -Zlinker-features=-lld' cargo build --release
docker build --no-cache --tag leovct/zk_evm:v0.6.0 .
```

Push the images.

```bash
docker login
docker push leovct/zk_evm:v0.6.0
```

Images are hosted on [Docker Hub](https://hub.docker.com/repository/docker/leovct/zk_evm/general) for the moment.

#### Build Jumpbox Image

This image contains the zk_evm binaries `leader`, `worker`, `rpc` and `verifier` as well as other dependencies and tools for proving and processing witnesses and proofs.

Clone `leovct/zk-evm-prover-infra`.

```bash
mkdir /opt/zk-evm-prover-infra
git clone https://github.com/leovct/zk-evm-prover-infra /opt/zk-evm-prover-infra
```

Build the jumpbox images.

```bash
pushd /opt/zk-evm-prover-infra/docker
docker build --no-cache --tag leovct/zk_evm_jumpbox:v0.6.0 --build-arg ZK_EVM_BRANCH_OR_COMMIT=v0.6.0 --file jumpbox.Dockerfile .
```

Check that the images are built correctly.

```bash
docker run --rm -it leovct/zk_evm_jumpbox:v0.6.0 /bin/bash
$ rpc --help
$ worker --help
$ leader --help
$ verifier --help
$ jq --version # jq-1.7.1
$ ps --version # ps from procps-ng 3.3.17
```

Push the images.

```bash
docker login
docker push leovct/zk_evm_jumpbox:v0.6.0
```

Images are hosted on [Docker Hub](https://hub.docker.com/repository/docker/leovct/zk_evm_jumpbox/general) for the moment.

</details>

## Proving Blocks

### Witness Generation Using Jerigon

<details>
<summary>Click to expand</summary>

[Jerrigon](https://github.com/0xPolygonZero/erigon/tree/feat/zero) is a fork of [Erigon](https://github.com/ledgerwatch/erigon) that allows seamless integration of [Polygon's Zk EVM Type 1 Prover](https://github.com/0xPolygonZero/zk_evm/tree/develop/zero_bin), facilitating the generation of witnesses and the proving of blocks using zero-knowledge proofs.

First, clone the Jerigon repository and check out the below commit hash.

```bash
git clone git@github.com:0xPolygonZero/erigon.git
pushd erigon
git checkout 83e0f2fa8c8f6632370e20fef7bbc8a4991c73c8 # TODO: Explain why we use this particular hash
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

Kurtosis enclave inspection should yield parity with the below.

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
git checkout v0.6.0
```

You are now ready to generate witnesses for any block of the L1 local chain using the zk_evm prover.

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

</details>

### Proof Generation

<details>
<summary>Click to expand</summary>

Get a running shell inside the `jumpbox` container.

```bash
jumpbox_pod_name="$(kubectl get pods --namespace zk-evm -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep zk-evm-jumpbox)"
kubectl exec --namespace zk-evm --stdin --tty "$jumpbox_pod_name" -- /bin/bash
```

Clone the repository and extract test witnesses.

```bash
git clone https://github.com/leovct/zk-evm-prover-infra.git /tmp/zk-evm-prover-infra
mkdir /tmp/witnesses
tar --extract --file=/tmp/zk-evm-prover-infra/witnesses/cancun/witnesses-20362226-to-20362237.tar.xz --directory=/tmp/witnesses --strip-components=1
```

In this test scenario, we will prove the two first blocks of a set of 10 blocks, which collectively contain 2181 transactions. In the next section, you can use the load tester tool to prove the 10 blocks in a row.

Get quick transaction data about each witness.

```bash
$ ./tmp/zk-evm-prover-infra/tools/analyze-witnesses.sh /tmp/witnesses 20362226 20362237
/tmp/witnesses/20362226.witness.json 166 txs
/tmp/witnesses/20362227.witness.json 174 txs
/tmp/witnesses/20362228.witness.json 120 txs
/tmp/witnesses/20362229.witness.json 279 txs
/tmp/witnesses/20362230.witness.json 177 txs
/tmp/witnesses/20362231.witness.json 164 txs
/tmp/witnesses/20362232.witness.json 167 txs
/tmp/witnesses/20362233.witness.json 238 txs
/tmp/witnesses/20362234.witness.json 216 txs
/tmp/witnesses/20362235.witness.json 200 txs
/tmp/witnesses/20362236.witness.json 92 txs
/tmp/witnesses/20362237.witness.json 188 txs
Total transactions: 2181
```

Let's attempt to prove the first witness.

```bash
folder="/tmp/witnesses"
witness_id=20362226
witness_file="$folder/$witness_id.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zk-evm.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Check the leader output.

```bash
2024-07-22T13:40:06.933510Z  INFO prover: Proving block 20362226
2024-07-22T14:57:35.314259Z  INFO prover: Successfully proved block 20362226
2024-07-22T14:57:35.319041Z  INFO leader::stdio: All proofs have been generated successfully.
// proof content
```

Format the proof content by extracting the proof out of the leader logs.

```bash
tail -n1 "$witness_file.leader.out" | jq empty # validation step
tail -n1 "$witness_file.leader.out" | jq > "$witness_file.proof.sequence"
tail -n1 "$witness_file.leader.out" | jq '.[0]' > "$witness_file.proof"
```

Now, let's attempt to prove the second witness using the first witness proof.

Notice how we specify the `--previous-proof` flag when proving a range of witnesses. Only the first witness in the range does not need this flag.

```bash
folder="/tmp/witnesses"
witness_id=20362227
witness_file="$folder/$witness_id.witness.json"
previous_proof="$folder/$(( witness_id - 1 )).witness.json.proof"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zk-evm.svc.cluster.local:5672 \
  stdio \
  --previous-proof "$previous_proof" < "$witness_file" | tee "$witness_file.leader.out"
```

Check the leader output

```bash
2024-07-24T08:12:13.855305Z  INFO prover: Proving block 20362227
2024-07-24T08:43:46.450954Z  INFO prover: Successfully proved block 20362227
2024-07-24T08:43:46.455782Z  INFO leader::stdio: All proofs have been generated successfully.
// proof content
```

Format the proof content by extracting the proof out of the leader logs.

```bash
tail -n1 "$witness_file.leader.out" | jq empty # validation step
tail -n1 "$witness_file.leader.out" | jq > "$witness_file.proof.sequence"
tail -n1 "$witness_file.leader.out" | jq '.[0]' > "$witness_file.proof"
```

Verify one of the generated proofs.

```bash
verifier --file-path 20362226.witness.json.proof.sequence
```

When running the command for the first time, the `verifier` will attempt to generate the circuits. This can take a few minutes.

```bash
2024-07-25T07:38:15.667883Z  INFO zero_bin_common::prover_state: initializing verifier state...
2024-07-25T07:38:15.667929Z  INFO zero_bin_common::prover_state: attempting to load preprocessed verifier circuit from disk...
2024-07-25T07:38:15.667975Z  INFO zero_bin_common::prover_state: failed to load preprocessed verifier circuit from disk. generating it...
2024-07-25T07:40:57.056064Z  INFO zero_bin_common::prover_state: saving preprocessed verifier circuit to disk
```

After a few seconds, the verification output will appear.

```bash
2024-07-25T07:41:02.600742Z  INFO verifier: All proofs verified successfully!
```

</details>

### Load Tester

<details>
<summary>Click to expand</summary>

You can deploy a load-tester tool that will attempt to prove 10 witnesses for a total of 2181 transactions. This is a great way to test that the setup works well.

```bash
kubectl apply --filename tools/zk-evm-load-tester.yaml --namespace zk-evm
```

To get the logs of the container, you can use:

```bash
kubectl logs deployment/zk-evm-load-tester --namespace zk-evm --container jumpbox --follow
```

Access a shell inside the load-tester pod.

```bash
kubectl exec deployment/zk-evm-load-tester --namespace zk-evm --container jumpbox -it -- bash
```

From there, you can list the witnesses, the leader outputs and the proofs.

Please note that the primary distinction between the `.proof` file and the `.proof.sequence` file lies in their content structure. The proof file contains only the `.proof` JSON element, whereas the `.proof.sequence` file encapsulates the proof JSON element within an array. The `.proof.sequence` file is intended for use with the `verifier`.

```bash
$ ls -al /data/witnesses
total 116976
drwxr-xr-x 2 root root     4096 Jul 25 07:25 .
drwxr-xr-x 4 root root     4096 Jul 24 16:38 ..
-rw-r--r-- 1 root root  8351244 Jul 22 12:59 20362226.witness.json
-rw-r--r-- 1 root root   438896 Jul 24 18:14 20362226.witness.json.leader.out
-rw-r--r-- 1 root root  1146468 Jul 24 18:14 20362226.witness.json.proof
-rw-r--r-- 1 root root  1213518 Jul 25 07:25 20362226.witness.json.proof.sequence
-rw-r--r-- 1 root root  8815832 Jul 22 12:59 20362227.witness.json
-rw-r--r-- 1 root root   438815 Jul 24 18:47 20362227.witness.json.leader.out
-rw-r--r-- 1 root root  1146387 Jul 24 18:47 20362227.witness.json.proof
-rw-r--r-- 1 root root  1213437 Jul 25 07:25 20362227.witness.json.proof.sequence
...
```

Verify one of the generated proofs.

```bash
verifier --file-path 20362226.witness.json.proof.sequence
```

After a few seconds, the verification output will appear.

```bash
2024-07-25T07:41:02.600742Z  INFO verifier: All proofs verified successfully!
```

</details>

## Feedback

- **Enhance `leader` logs to be more operator-friendly**.

  Currently, the logs lack detailed progress information during the proving process. It would be beneficial to display the progress of the proof, including metrics like the number of transactions proved, total transactions, and time elapsed (essentially a progress bar showing % of transactions proven in a block so far).

  We should go from this:

  ```bash
  $ cat /tmp/witnesses/20362226.witness.json.leader.out
  2024-07-23T12:20:20.216474Z  INFO prover: Proving block 20362226
  2024-07-23T12:49:39.228506Z  INFO prover: Successfully proved block 20362226
  2024-07-23T12:49:39.232793Z  INFO leader::stdio: All proofs have been generated successfully.
  [{"b_height":20362226,"intern":{"proof":{"wires_cap":[{"elements":[4256508008463016688,1783014170904099315,1260603897523273593,8950237682820889684]},{"elements":[15374648482258556351,3883067792593597294,16855708440532655062,892216457806275301]}
  ...
  ```

  To something like this, where we don't log the proof.

  ```bash
  $ cat /tmp/witnesses/20362226.witness.json.leader.out
  2024-07-23T12:20:20.216474Z  INFO prover: Proving block 20362226 txs_proved=0 total_txs=166 time_spent=0s
  2024-07-23T12:20:21.216474Z  INFO prover: Proving block 20362226 txs_proved=9 total_txs=166 time_spent=60s
  2024-07-23T12:20:22.216474Z  INFO prover: Proving block 20362226 txs_proved=23 total_txs=166 time_spent=120s
  ...
  2024-07-23T12:49:39.228506Z  INFO prover: Successfully proved block 20362226 txs=166 time_spent=1203s
  2024-07-23T12:49:39.232793Z  INFO leader::stdio: All proofs have been generated successfully
  ```

- **Add Proof File Output Flag to `leader` Subcommand**

  Implement a new flag in the `leader` subcommand to enable storing proofs in files instead of outputting them to stdout. This enhancement will improve log readability and simplify proof management by keeping proof data separate from log output. The flag could be something like `--output-proof-file`, allowing users to easily switch between file output and stdout as needed.

- **Enhance `worker` logs to be more operator-friendly**.

  Instead of reporting `id="b20362227 - 79"`, the application should report `block_hash=b20362227` and `tx_id=79`.

  Example of unclear values currently appearing in the zk_evm prover logs:

  ```bash
  2024-07-23T14:08:04.372779Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 131072 cycles     id="b20362227 - 79"
  ```

- **Add Prometheus metrics to `zero-bin`**
  - Each metric should be labeled with `block_hash` and `tx_id`.
  - Relevant metrics could include `witnesses_proved`, `cpu_halts`, `cpu_trace_pads`, `and` trace_lengths.
  - This would supercharge the DevTools team's ability to catch and debug critical system issues

- **Add Version Subcommand**

  ```bash
  leader --version
  ```

- **Manage AMQP Cluster State**

  Develop a tool or command to manage the state of the AMQP cluster. This should include capabilities to clear the state of queues or remove specific block proof tasks.

  For example, right now, there is no way to stop the provers once it has been fed a range of witnesses via the AMQP cluster. If many complicated witnesses pile up for proving, it is very difficult for the system to catch up unless we have some AMQP state management tooling for local testing and development.

## Next Steps

- [ ] Automatic prover benchmarking suite, including metric collection and visualization (in progress).

- [ ] Solve the problem when scaling zk_evm workers across multiple nodes. The circuit volume is only accessible on a single node, regardless of the access mode, `ReadWriteOnce` or `ReadWriteMany`. This limitation may be due to the way we have configured the GKE cluster.

- [ ] The leader communicates with the pool of workers through RabbitMQ by creating a queue by proof request. However, [RabbitMQ Queue](https://keda.sh/docs/2.14/scalers/rabbitmq-queue/) can only scale the number of workers based on the size of the message backlog (for a specific queue), or the publish/sec rate. It looks like there is no way to scale the number of workers based on the total message backlog across all queues!? I asked the [question](https://kubernetes.slack.com/archives/CKZJ36A5D/p1718671628824279) in the Kubernetes Slack. We'll maybe need to switch to another way of scaling, maybe measuring CPU/MEM usage.

- [ ] The setup does not use any `jerrigon` node to generate the witnesses, instead, we provide the witnesses directly to the leader. This should be changed, especially because we would like to be able to follow the tip of the chain. We would then need to detect the new block (and probably introduce some kind of safety mechanism to make sure the block won't get reorged), generate a witness for the block and prove the block using the witness.
