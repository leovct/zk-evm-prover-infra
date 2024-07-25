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

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "The name of the VPC"
}

output "kubernetes_version" {
  value       = google_container_cluster.primary.master_version
  description = "The Kubernetes version of the master"
}
