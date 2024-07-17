output "project_id" {
  value       = var.project_id
  description = "The ID of the Google Cloud project where resources are deployed"
}

output "region" {
  value       = var.region
  description = "The Google Cloud region where the GKE cluster is located"
}

output "zones" {
  value       = var.zones
  description = "The Google Cloud zones where the GKE cluster nodes are located"
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster"
}

output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  description = "The IP address of the GKE cluster's Kubernetes master"
}

output "kubernetes_version" {
  value       = google_container_cluster.primary.master_version
  description = "The Kubernetes version of the master"
}

output "node_pools" {
  value       = google_container_cluster.primary.node_pool[*].name
  description = "The names of the node pools in the GKE cluster"
}
