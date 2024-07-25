#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Check if required commands are available.
command -v gcloud >/dev/null 2>&1 || { echo "gcloud is required but not installed."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed."; exit 1; }

# GKE Cluster Setup.
echo "Authenticating with GCP account..."
gcloud auth application-default login

echo; echo "Checking current GCP project..."
gcloud config get-value project

echo; echo "Deploying GKE infrastructure with Terraform..."
echo; echo "It may take approximately 10 minutes."
pushd terraform
terraform init
terraform apply
popd

# Get GKE cluster info.
CLUSTER_NAME=$(terraform -chdir=terraform output -raw kubernetes_cluster_name)
REGION=$(terraform -chdir=terraform output -raw region)

# Zk EVM Prover Infrastructure Setup.
echo; echo "Authenticating with GCP account for kubectl..."
gcloud auth login

echo; echo "Getting access to the GKE cluster config..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION"

echo; echo "Verifying access to the GKE cluster..."
kubectl get nodes

echo; echo "Installing RabbitMQ Cluster Operator..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq-cluster-operator bitnami/rabbitmq-cluster-operator \
  --version 4.3.14 \
  --namespace rabbitmq-cluster-operator \
  --create-namespace

echo; echo "Installing KEDA..."
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  --version 2.14.2 \
  --namespace keda \
  --create-namespace

echo; echo "Installing Prometheus Operator..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --version 61.3.1 \
  --namespace kube-prometheus \
  --create-namespace

echo; echo "Deploying zk_evm prover infrastructure..."
helm install test --namespace zk-evm --create-namespace ./helm

echo; echo "Setup completed successfully!"
echo; echo "It may take a few minutes for all pods to be ready."
