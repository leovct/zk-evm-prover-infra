## Running the Script

## Port-forward with Prometheus API:
# 1. kubectl port-forward --namespace kube-prometheus --address localhost svc/prometheus-operated 9090:9090

## In another terminal, run prover load test script with witness download (optional):
# 2. python3 tools/scripts/run_proofs.py --total_tasks 1 --starting_block 20241377 --download_witnesses

# This script dynamically retrieves jumpbox pod name, sets up required directories, 
# optionally downloads witnesses, triggers proofs via the jumpbox, and captures all relevant metrics

import time
import csv
import requests
import subprocess
from datetime import datetime, timedelta
from urllib.parse import urlencode
import argparse
import json

# Update the URL with the correct service name and port
PROMETHEUS_URL = 'http://localhost:9090/api/v1/query_range'
TASK_CUTOFF = 600  # task cutoff duration in seconds
BUFFER_WAIT_TIME = 20  # buffer time before, after task, and time to wait after task completion for metrics to land

NAMESPACE = 'zero'  # Update with your actual namespace

def test_prometheus_connection():
    try:
        response = requests.get('http://localhost:9090/api/v1/targets')
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print("Error connecting to Prometheus:", e)
        exit(1)

def get_jumpbox_pod_name():
    try:
        result = subprocess.run(
            ['kubectl', 'get', 'pods', '--namespace', NAMESPACE, '-l', 'app=jumpbox', '-o', 'json'],
            capture_output=True, text=True, timeout=30)
        pods = json.loads(result.stdout)
        if pods['items']:
            return pods['items'][0]['metadata']['name']
        else:
            print("No jumpbox pod found.")
            exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Failed to get jumpbox pod name: {e.stderr}")
        exit(1)

def setup_jumpbox_environment(jumpbox_pod_name, download_witnesses):
    commands = [
        'mkdir -p /tmp/proofs',
        'mkdir -p /tmp/witnesses'
    ]

    if download_witnesses:
        commands.extend([
            'pushd /tmp',
            'curl -L --output witnesses.xz https://cf-ipfs.com/ipfs/QmTk9TyuFwA7rjPh1u89oEp8shpFUtcdXuKRRySZBfH1Pu',
            'tar --extract --file=/tmp/witnesses.xz --directory=/tmp/witnesses --strip-components=1 --checkpoint=10000 --checkpoint-action=dot',
            'rm /tmp/witnesses.xz',
            'popd'
        ])

    for command in commands:
        print(f"Executing setup command on jumpbox: {command}")
        try:
            result = subprocess.run(
                ['kubectl', 'exec', jumpbox_pod_name, '--namespace', NAMESPACE, '--', 'sh', '-c', command],
                capture_output=True, text=True)
            if result.stderr:
                print(f"Setup command error: {result.stderr}")
        except subprocess.CalledProcessError as e:
            print(f"Setup command failed with error: {e.stderr}")

def execute_task(starting_block, jumpbox_pod_name):
    witness_file = f'/tmp/witnesses/{starting_block:08d}.witness.json'
    output_file = f'/tmp/proofs/proof-{starting_block:08d}.leader.out'

    command = f"""
    env RUST_BACKTRACE=full RUST_LOG=debug leader --runtime=amqp --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 stdio < {witness_file} &> {output_file}
    """
    
    print(f"Executing command on jumpbox: kubectl exec {jumpbox_pod_name} --namespace {NAMESPACE} -- sh -c '{command}'")

    try:
        result = subprocess.run(
            ['kubectl', 'exec', jumpbox_pod_name, '--namespace', NAMESPACE, '--', 'sh', '-c', command],
            capture_output=True, text=True, timeout=TASK_CUTOFF)
        print(f"Command output: {result.stdout}")
        print(f"Command error: {result.stderr}")
        return result.stdout, result.stderr if result.stderr else None
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e.stderr}")
        return None, e.stderr
    except subprocess.TimeoutExpired:
        print(f"Command timed out after {TASK_CUTOFF} seconds.")
        return None, "Task execution exceeded the cutoff time."

def fetch_prometheus_metrics(starting_block, start_time, end_time):
    queries = {
        'cpu_usage': 'rate(container_cpu_usage_seconds_total[1m])',
        'memory_usage': 'container_memory_usage_bytes',
        'disk_read': 'rate(node_disk_read_bytes_total[1m])',
        'disk_write': 'rate(node_disk_written_bytes_total[1m])',
        'network_receive': 'rate(node_network_receive_bytes_total[1m])',
        'network_transmit': 'rate(node_network_transmit_bytes_total[1m])'
    }
    
    metrics = []
    for name, query in queries.items():
        start_str = start_time.replace(microsecond=0).isoformat() + "Z"
        end_str = end_time.replace(microsecond=0).isoformat() + "Z"
        params = {
            'query': query,
            'start': start_str,
            'end': end_str,
            'step': '15s'  # Adjust the step interval as needed
        }
        # Encode parameters for URL
        url = PROMETHEUS_URL + '?' + urlencode(params)
        print(f"Fetching {name} metrics from URL: {url}")
        
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        # print(f"Response data: {data}")  # Print the entire response for debugging
        metrics.append((name, data['data']['result']))
    
    return metrics

def log_metrics_to_csv(starting_block, metrics):
    with open('metrics.csv', mode='a', newline='') as file:
        writer = csv.writer(file)
        for metric_name, metric_data in metrics:
            row = [starting_block, datetime.now(), metric_name]
            for metric in metric_data:
                values = [value[1] for value in metric['values']]
                row.extend(values)
            writer.writerow(row)

def log_error(starting_block, error_log):
    with open(f'error_{starting_block}.log', mode='w') as file:
        file.write(error_log)

def main(total_tasks, starting_block, download_witnesses):
    test_prometheus_connection()
    jumpbox_pod_name = get_jumpbox_pod_name()
    
    setup_jumpbox_environment(jumpbox_pod_name, download_witnesses)
    
    for task in range(total_tasks):
        current_block = starting_block + task
        print(f"Starting task {current_block}")

        # Determine the time range for metrics collection
        start_time = datetime.utcnow() - timedelta(seconds=BUFFER_WAIT_TIME)
        end_time = datetime.utcnow() + timedelta(seconds=BUFFER_WAIT_TIME)

        # Execute the task
        task_start_time = datetime.utcnow()
        output, error = execute_task(current_block, jumpbox_pod_name)
        task_end_time = datetime.utcnow()

        # Check if command was executed successfully
        if output:
            print(f"Task {current_block} executed successfully.")
        else:
            print(f"Task {current_block} failed to execute.")

        # Wait for metrics to land
        time.sleep(BUFFER_WAIT_TIME)

        # Fetch Prometheus metrics
        metrics = fetch_prometheus_metrics(current_block, start_time, end_time)

        # Log metrics to CSV
        log_metrics_to_csv(current_block, metrics)

        # Log errors if any
        if error:
            log_error(current_block, error)

        print(f"Completed task {current_block}")

        # Cool-down period
        time.sleep(BUFFER_WAIT_TIME)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run block proving tasks and collect performance metrics.')
    parser.add_argument('--total_tasks', type=int, default=1, help='Total number of tasks to execute.')
    parser.add_argument('--starting_block', type=int, default=20241088, help='Starting block number.')
    parser.add_argument('--download_witnesses', action='store_true', help='Flag to download witnesses.')

    args = parser.parse_args()
    main(args.total_tasks, args.starting_block, args.download_witnesses)
