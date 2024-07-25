# DEBUG2

Download the new witness archive (`witnesses/cancun/witnesses-20362226-to-20362237.tar`) created by John.

```bash
git clone https://github.com/leovct/zk-evm-prover-infra.git /tmp/zk-evm-prover-infra
mkdir /tmp/witnesses
tar --extract --file=/tmp/zk-evm-prover-infra/witnesses/cancun/witnesses-20362226-to-20362237.tar.xz --directory=/tmp/witnesses --strip-components=1
```

Quick analysis of the number of witnesses.

```bash
$ /tmp/zk-evm-prover-infra/tools/analyze-witnesses.sh /tmp/witnesses 20362226 20362237
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

Attempt to prove the first witness.

```bash
folder="/tmp/witnesses"
witness_id=20362226
witness_file="$folder/$witness_id.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Check the leader output.

```bash
2024-07-22T13:40:06.933510Z  INFO prover: Proving block 20362226
2024-07-22T14:57:35.314259Z  INFO prover: Successfully proved block 20362226
2024-07-22T14:57:35.319041Z  INFO leader::stdio: All proofs have been generated successfully.
// proof content
```

Format the proof content.

```bash
tail -n +4 "$witness_file.leader.out" | jq empty
tail -n +4 "$witness_file.leader.out" | jq '.[0]' > "$witness_file.proof"
```

Attempt to prove the second witness using the first witness proof.

```bash
folder="/tmp/witnesses"
witness_id=20362227
witness_file="$folder/$witness_id.witness.json"
previous_proof="$folder/$(( witness_id - 1 )).witness.json.proof"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio \
  --previous-proof "$previous_proof" < "$witness_file" | tee "$witness_file.leader.out"
```

Check the leader output.

```bash
2024-07-24T08:12:13.855305Z  INFO prover: Proving block 20362227
2024-07-24T08:43:46.450954Z  INFO prover: Successfully proved block 20362227
2024-07-24T08:43:46.455782Z  INFO leader::stdio: All proofs have been generated successfully.
// proof content
```

Format the proof content.

```bash
tail -n +4 "$witness_file.leader.out" | jq empty
tail -n +4 "$witness_file.leader.out" | jq '.[0]' > "$witness_file.proof"
```

Now, let's use a script to automate the proving of a range of witnesses.

```bash
/tmp/zk-evm-prover-infra/tools/prove-witnesses.sh /tmp/witnesses 20362226 20362237
```

Note that for the purpose of the test, we used a `c3d-highmem-180` instance (180 vCPU / 1.44TB of memory) and we deployed 3 workers on the node.

We manage to prove approximately 100 transactions every 20 minutes, equating to a speed of 300 transactions per hour. Given that there are around 2200 transactions to prove, it would take roughly 7 hours and 20 minutes to prove the range of 10 blocks with the given setup.

The experiment demonstrates that a single worker can process approximately 100 transactions per hour. Adding a fourth worker to our current three-worker setup could potentially reduce the total proving time from about 7 hours and 20 minutes to approximately 5 hours and 30 minutes, saving around 1 hour and 50 minutes.

However, it's crucial to consider that workers may require substantial memory depending on the complexity of transactions being proved, which could lead to out-of-memory (OOM) errors... Given the cluster metrics, the first block never requires more than 50GB to prove a transaction. It is safe to deploy two additional workers for now.

![cluster-metrics](./debug2-cluster-metrics.png)

## Handy Commands

Clean the `witnesses` folder. This will delete all leader outputs and proofs, only keeping witnesses.

```bash
find /tmp/witnesses/ -type f ! -name "*.witness.json" -exec rm -f {} +
```