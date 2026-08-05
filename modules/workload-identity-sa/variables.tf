variable "project_id" {
  description = "GCP project ID that owns the SA"
  type        = string
}

variable "sa_name" {
  description = "GCP service account name (the part before @project.iam.gserviceaccount.com)"
  type        = string
}

variable "display_name" {
  description = "Human-readable name shown in the Console"
  type        = string
}

variable "roles" {
  description = "IAM roles to grant to this SA at project scope"
  type        = list(string)
  default     = []
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the k8s SA that will impersonate this GCP SA"
  type        = string
}

variable "k8s_sa_name" {
  description = "Name of the k8s SA that will impersonate this GCP SA"
  type        = string
}
