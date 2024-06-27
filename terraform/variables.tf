variable "project_id" {
  type    = string
  default = "jihwan-cdk-test"
}
variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}
variable "region" {
  type    = string
  default = "europe-west3"
}
variable "default_node_type" {
  type    = string
  default = "e2-standard-16"
}
variable "highmem_node_type" {
  type    = string
  default = "t2d-standard-32"
}
variable "node_locations" {
  description = "List of availability zones within the region"
  type        = list(string)
  default     = ["europe-west3-c"]
}
variable "node_disk_size" {
  type = number
  default = 300
}