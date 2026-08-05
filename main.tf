provider "google" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# Network: VPC + subnet with secondary ranges for pods and services, Cloud NAT
# -----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id

  # Secondary ranges consumed by GKE for pod and service IPs (VPC-native cluster)
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "main" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# -----------------------------------------------------------------------------
# GKE cluster (zonal, VPC-native, Workload Identity enabled)
# -----------------------------------------------------------------------------

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.zone # zonal cluster = single-zone control plane, cheapest

  # Manage the node pool as a separate resource - the default one is throwaway
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.cluster.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable Workload Identity at cluster level
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Portfolio demo lifecycle: apply -> demo -> destroy same day
  deletion_protection = false
}

resource "google_container_node_pool" "main" {
  name       = "primary"
  location   = var.zone
  cluster    = google_container_cluster.main.name
  node_count = var.node_count_min

  autoscaling {
    min_node_count = var.node_count_min
    max_node_count = var.node_count_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 30
    disk_type    = "pd-standard"

    service_account = google_service_account.node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # GKE_METADATA is required on the node pool for Workload Identity to work
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# -----------------------------------------------------------------------------
# Node service account (minimal permissions - no default Compute SA editor grant)
# -----------------------------------------------------------------------------

resource "google_service_account" "node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_project_iam_member" "node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_project_iam_member" "node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_project_iam_member" "node_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.node.email}"
}

# -----------------------------------------------------------------------------
# Workload Identity demo: a GCP SA that a k8s SA `default/gcs-reader` can
# impersonate. Analogous to the s3-reader IRSA demo in terraform-eks-platform.
# k8s SA creation is intentionally out of scope for v1 (manual kubectl step,
# documented in README).
# -----------------------------------------------------------------------------

module "gcs_reader" {
  source = "./modules/workload-identity-sa"

  project_id    = var.project_id
  sa_name       = "gcs-reader"
  display_name  = "GCS Reader (Workload Identity demo)"
  roles         = ["roles/storage.objectViewer"]
  k8s_namespace = "default"
  k8s_sa_name   = "gcs-reader"

  # The Workload Identity pool `PROJECT.svc.id.goog` is provisioned
  # asynchronously by the cluster when workload_identity_config is set.
  # Without this explicit dependency, Terraform attempts the WI binding
  # before the pool exists and fails with 400 "Identity Pool does not
  # exist" on a clean apply. Race caught by CI on the first real apply,
  # 2026-08-05.
  depends_on = [google_container_cluster.main]
}
