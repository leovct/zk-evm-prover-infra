# DEBUG3

Attempt to prove the big witness.

```bash
folder="/tmp/zk-evm-prover-infra/witnesses/cancun"
witness_id=20362226
witness_file="$folder/$witness_id.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```
