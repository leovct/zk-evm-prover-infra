variable "deployment_name" {
  type        = string
  description = "Unique identifier for this deployment, used as a prefix for all associated resources"
}

variable "environment" {
  type        = string
  description = "Specifies the deployment environment (e.g., development, staging, production) for configuration purposes"
}

variable "project_id" {
  type        = string
  description = "The unique identifier of the Google Cloud Platform project for resource deployment and billing"
  default     = "prj-polygonlabs-devtools-dev"
}

variable "region" {
  type        = string
  description = "The Google Cloud Platform region where resources will be created"
  default     = "europe-west3"
}

variable "zones" {
  type        = list(string)
  description = "List of availability zones within the region for distributing resources and enhancing fault tolerance"
  default     = ["europe-west3-b"]
}

variable "owner" {
  type        = string
  description = "The primary point of contact for this deployment"
}

// Kubernetes settings

variable "use_spot_instances" {
  type        = bool
  description = "Whether to use spot instances or not for the GKE cluster"
  default     = true
}

// Default node pool

variable "default_pool_node_count" {
  type        = number
  description = "Number of nodes in the GKE cluster's default node pool"
  default     = 1
}

variable "default_pool_machine_type" {
  type        = string
  description = "Machine type for nodes in the default node pool, balancing performance and cost"
  default     = "e2-standard-16"
  // - e2-standard-16 (16 vCPU / 64GB of memory)
}

variable "default_pool_node_disk_size_gb" {
  type        = number
  description = "The size (in GB) of the disk attached to each node in the default node pool"
  default     = 300
}

// Highmem node pool

variable "highmem_pool_node_count" {
  type        = number
  description = "Number of nodes in the GKE cluster's highmem node pool"
  default     = 1
}

variable "highmem_pool_machine_type" {
  type        = string
  description = "Machine type for nodes in the highmem node pool, optimized for memory-intensive workloads"
  default     = "t2d-standard-60"
  // https://gcloud-compute.com/instances.html
  // - t2d-standard-32 (32 vCPU / 128GB of memory)
  // - t2d-standard-60 (60 vCPU / 240GB of memory)
  // - c3d-highmem-60  (60 vCPU / 480GB of memory)
  // - c3d-highmem-90  (90 vCPU / 720GB of memory)
  // - c3d-highmem-180 (180 vCPU / 1.44TB of memory)
  // - c3d-highmem-360 (360 vCPU / 2.88TB of memory)
}

variable "highmem_pool_node_disk_size_gb" {
  type        = number
  description = "The size (in GB) of the disk attached to each node in the highmem node pool"
  default     = 100
}
