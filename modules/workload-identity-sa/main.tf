# Workload Identity binding module
#
# Creates a GCP service account, grants project-scoped IAM roles to it, and
# binds `roles/iam.workloadIdentityUser` for a specific Kubernetes SA path
# (`namespace/sa_name`) so that a pod running under that k8s SA can impersonate
# this GCP SA via the cluster's Workload Identity pool.
#
# The k8s SA itself is intentionally NOT managed here - creation and annotation
# happen out-of-band (kubectl for v1; kubernetes_service_account resource in v2).
# This mirrors the modules/irsa-role split in terraform-eks-platform.

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.sa_name
  display_name = var.display_name
}

resource "google_project_iam_member" "this" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_sa_name}]"
}
