output "cluster_name" {
  value       = google_container_cluster.main.name
  description = "GKE cluster name"
}

output "cluster_location" {
  value       = google_container_cluster.main.location
  description = "GKE cluster location (zone for zonal cluster)"
}

output "cluster_endpoint" {
  value       = google_container_cluster.main.endpoint
  description = "Kubernetes API endpoint"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  description = "Base64-encoded cluster CA certificate"
  sensitive   = true
}

output "node_service_account" {
  value       = google_service_account.node.email
  description = "Email of the service account attached to node pool VMs"
}

output "gcs_reader_sa" {
  value       = module.gcs_reader.sa_email
  description = "Email of the Workload Identity demo GCP SA (impersonated by k8s SA default/gcs-reader)"
}

output "kubectl_get_credentials" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${google_container_cluster.main.location} --project ${var.project_id}"
  description = "Ready-to-run gcloud command to configure kubectl for this cluster"
}

output "kubectl_annotate_gcs_reader" {
  value       = module.gcs_reader.kubectl_annotate_command
  description = "kubectl command to wire the k8s SA to the WI demo GCP SA (v1 manual step)"
}
