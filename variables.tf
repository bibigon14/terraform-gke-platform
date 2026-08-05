variable "project_id" {
  description = "GCP project ID (from bootstrap step 2)"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources (VPC subnet, Cloud NAT)"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "GCP zone for the zonal GKE cluster"
  type        = string
  default     = "us-west1-a"
}

variable "cluster_name" {
  description = "GKE cluster name; also used as prefix for VPC / subnet / router / NAT / node SA"
  type        = string
  default     = "gke-platform-demo"
}

variable "subnet_cidr" {
  description = "Primary CIDR for the cluster subnet (node IPs)"
  type        = string
  default     = "10.30.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for pod IPs (VPC-native)"
  type        = string
  default     = "10.31.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for service ClusterIPs"
  type        = string
  default     = "10.32.0.0/20"
}

variable "node_machine_type" {
  description = "GCE machine type for node pool VMs"
  type        = string
  default     = "e2-medium"
}

variable "node_count_min" {
  description = "Autoscaling minimum node count"
  type        = number
  default     = 1
}

variable "node_count_max" {
  description = "Autoscaling maximum node count"
  type        = number
  default     = 3
}
