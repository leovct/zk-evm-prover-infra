# GKE cluster
data "google_container_engine_versions" "gke_version" {
  location = var.region
  # version_prefix = "1.27."
}

resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-zero-prover-gke"
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

}

# Separately Managed Default Node Pool
resource "google_container_node_pool" "default_nodes" {
  name       = "default-nodes-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_locations = var.node_locations

  # version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = var.default_node_type
    tags         = ["zero-prover-gke-node", "${var.project_id}-zero-prover-gke"]
    disk_size_gb = var.node_disk_size
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# Separately Managed Highmem Node Pool
resource "google_container_node_pool" "highmem_nodes" {
  name       = "highmem-nodes-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_locations = var.node_locations
  
  # version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = var.highmem_node_type
    tags         = ["zero-prover-gke-node", "${var.project_id}-zero-prover-gke"]
    disk_size_gb = var.node_disk_size
    metadata = {
      disable-legacy-endpoints = "true"
    }
    taint{
      key = "highmem"
      value = true
      effect = "NO_SCHEDULE"
    }
  }
}