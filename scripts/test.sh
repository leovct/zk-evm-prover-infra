#!/bin/bash
set -euo pipefail

# List of witness numbers to process
witness_numbers=(0000 0001 0034 0036 0128)

total_files=${#witness_numbers[@]}
successful_proofs=0
failed_proofs=0

start_time=$(date +%s)
echo "Starting script at $(date)"

# Function to run the command for a single witness
run_proof() {
  local n=$1
  local witness="data/witness-$n.json"
  local output="data/leader-$n.out"

  env RUST_BACKTRACE=full RUST_LOG=debug leader \
    --runtime=amqp \
    --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
    stdio < "$witness" &> "$output"

  if [ $? -eq 0 ]; then
    echo "Successfully proved witness-$n.json"
    ((successful_proofs++))
  else
    echo "Failed to prove witness-$n.json"
    ((failed_proofs++))
  fi
}

export -f run_proof

# Run the proofs in parallel using GNU Parallel
parallel --jobs 0 run_proof ::: "${witness_numbers[@]}"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Script completed in $duration seconds"
echo "Total files processed: $total_files"
echo "Successful runs: $successful_proofs"
echo "Failed runs: $failed_proofs"
