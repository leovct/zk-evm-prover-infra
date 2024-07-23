#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Analyze a range of witnesses.
analyze_witness_range() {
  local start_id=$1
  local end_id=$2
  local total_tx=0

  for ((witness_id=start_id; witness_id<=end_id; witness_id++)); do
    witness_file="$WITNESS_DIR/${witness_id}.witness.json"

    if [ ! -f "$witness_file" ]; then
      echo "Warning: Witness file $witness_file does not exist. Skipping."
      continue
    fi

    tx_count=$(jq '.[0].block_trace.txn_info | length' "$witness_file")
    echo "$witness_file $tx_count txs"
    total_tx=$((total_tx + tx_count))
  done

  echo "Total transactions: $total_tx"
}

# Set variables from command line arguments.
WITNESS_DIR=$1
START_WITNESS_ID=$2
END_WITNESS_ID=$3

# Validate input.
if [ ! -d "$WITNESS_DIR" ]; then
  echo "Error: Directory $WITNESS_DIR does not exist."
  exit 1
fi

if [ $START_WITNESS_ID -gt $END_WITNESS_ID ]; then
  echo "Error: Start witness ID must be less than or equal to end witness ID."
  exit 1
fi

# Analyze witness range.
analyze_witness_range $START_WITNESS_ID $END_WITNESS_ID
