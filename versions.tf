terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Backend config is passed via -backend-config from CI (from repo variables
  # TF_STATE_BUCKET / TF_STATE_PREFIX) or from a local backend.hcl during dev.
  # See docs/bootstrap.md for how these were created.
  backend "gcs" {}
}
