resource "google_container_cluster" "primary" {
  name       = "${var.deployment_name}-gke-cluster"
  project    = var.project_id
  location   = var.region
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  // It is not possible to create a GKE cluster without any node pool.
  // Since we want to manage node pools separately, we create the smallest possible default node pool before deleting it.
  initial_node_count       = 1
  remove_default_node_pool = true
}

locals {
  labels = {
    owner       = var.owner
    environment = var.environment
  }
  tags = ["zero-prover-gke-node", "${var.deployment_name}-gke-cluster"]
  oauth_scopes = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
  ]
  metadata = {
    disable-legacy-endpoints = "true"
  }
}

resource "google_container_node_pool" "default_node_pool" {
  name           = "default-node-pool"
  project        = var.project_id
  location       = var.region
  node_locations = var.zones

  cluster    = google_container_cluster.primary.name
  node_count = var.default_pool_node_count
  node_config {
    machine_type = var.default_pool_machine_type
    disk_size_gb = var.default_pool_disk_size_gb

    labels          = local.labels // GKE resources
    resource_labels = local.labels // GCP resources
    tags            = local.tags
    oauth_scopes    = local.oauth_scopes
    metadata        = local.metadata
  }
}

resource "google_container_node_pool" "highmem_node_pool" {
  name           = "highmem-node-pool"
  project        = var.project_id
  location       = var.region
  node_locations = var.zones

  cluster    = google_container_cluster.primary.name
  node_count = var.highmem_pool_node_count

  node_config {
    machine_type = var.highmem_pool_machine_type
    disk_size_gb = var.highmem_pool_disk_size_gb
    disk_type    = "pd-ssd"

    taint {
      key    = "highmem"
      value  = true
      effect = "NO_SCHEDULE"
    }

    labels          = local.labels // GKE resources
    resource_labels = local.labels // GCP resources
    tags            = local.tags
    oauth_scopes    = local.oauth_scopes
    metadata        = local.metadata
  }
}
