#!/bin/bash
set -uo pipefail

# List of witness to process.
witnesses=(/tmp/test-data/432.erc721.witness.json /tmp/test-data/512.eoa.witness.json /tmp/test-data/512.erc20.witness.json)

total_files=${#witnesses[@]}
successful_proofs=0
failed_proofs=0

start_time=$(date +%s)
echo "Starting script at $(date)"

# Function to run to prove a single block, given a witness.
run_proof() {
  local witness="$1"
  echo -e "\n> Generating proof for $witness..."
  env RUST_BACKTRACE=full RUST_LOG=debug leader \
    --runtime=amqp \
    --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
    stdio < "$witness"

  if [ $? -eq 0 ]; then
    echo "> Successfully proved $witness"
    ((successful_proofs++))
  else
    echo "> Failed to prove $witness"
    ((failed_proofs++))
  fi
}

# Generate the proofs using a for loop.
for witness in "${witnesses[@]}"; do
  run_proof "$witness"
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo -e "\nScript completed in $duration seconds"
echo "Total files processed: $total_files"
echo "Successful runs: $successful_proofs"
echo "Failed runs: $failed_proofs"
