output "sa_email" {
  value       = google_service_account.this.email
  description = "Email of the created GCP SA (annotate the k8s SA with this)"
}

output "sa_id" {
  value       = google_service_account.this.id
  description = "Full resource ID of the created GCP SA"
}

output "kubectl_annotate_command" {
  value       = "kubectl annotate serviceaccount ${var.k8s_sa_name} -n ${var.k8s_namespace} iam.gke.io/gcp-service-account=${google_service_account.this.email}"
  description = "Command to annotate the k8s SA with the GCP SA email (v1 manual step)"
}
