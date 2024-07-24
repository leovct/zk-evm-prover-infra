#!/bin/bash
set -x # Print each command before executing it.
set -e # Exit immediately if a command exits with a non-zero status.

# Prove a range of witnesses.
prove_witness_range() {
  local start_id=$1
  local end_id=$2

  if ! prove_initial_witness $start_id; then
    echo "Error: Failed to prove initial witness $start_id"
    return 1
  fi
}

# Prove the initial witness, without any previous proof.
prove_initial_witness() {
  local witness_id=$1
  local witness_file="$WITNESS_DIR/$witness_id.witness.json"
  local leader_output="$witness_file.leader.out"

  env RUST_BACKTRACE=full RUST_LOG=info \
    leader \
    --runtime=amqp \
    --amqp-uri=$AMQP_URI \
    stdio < "$witness_file" | tee "$leader_output"

  format_proof "$leader_output" "$witness_file.proof"
}

# Prove subsequent witnesses, with previous proof.
prove_subsequent_witness() {
  local witness_id=$1
  local previous_proof=$2
  local witness_file="$WITNESS_DIR/$witness_id.witness.json"
  local leader_output="$witness_file.leader.out"

  env RUST_BACKTRACE=full RUST_LOG=info \
    leader \
    --runtime=amqp \
    --amqp-uri=$AMQP_URI \
    stdio \
    --previous-proof "$previous_proof" < "$witness_file" | tee "$leader_output"

  format_proof "$leader_output" "$witness_file.proof"
}

# Format the proof content.
format_proof() {
  local leader_output=$1
  local proof_file=$2
  tail -n +4 "$leader_output" | jq '.[0]' > "$proof_file"
}

# Check if correct number of arguments is provided.
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <witness_directory> <start_witness_id> <end_witness_id>"
  exit 1
fi

# Set variables from command line arguments.
WITNESS_DIR=$1
START_WITNESS_ID=$2
END_WITNESS_ID=$3
AMQP_URI=$4

# Set AMQP URI.
AMQP_URI="amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672"

# Validate input.
if [ ! -d "$WITNESS_DIR" ]; then
  echo "Error: Directory $WITNESS_DIR does not exist."
  exit 1
fi

if [ $START_WITNESS_ID -gt $END_WITNESS_ID ]; then
  echo "Error: Start witness ID must be less than or equal to end witness ID."
  exit 1
fi

# Prove witness range.
prove_witness_range $START_WITNESS_ID $END_WITNESS_ID
