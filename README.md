# terraform-gke-platform

Portfolio project: a production-shaped GKE-on-GCP platform, provisioned end-to-end with Terraform and GitHub Actions with no local `terraform apply` in the loop.

Designed to be `apply`ed, demoed, and `destroy`ed the same day. Not a long-running install.

Companion to [terraform-eks-platform](https://github.com/bibigon14/terraform-eks-platform) - same shape, different cloud.

## Architecture

_TODO: Mermaid diagram once `main.tf` lands._

## Stack

- GKE Standard (zonal), Kubernetes 1.30
- VPC-native cluster with dedicated subnet + secondary ranges for pods and services
- Workload Identity Federation for GitHub Actions -> GCP auth (no service account keys committed anywhere)
- GCS backend with generation-number state locking (no separate lock table)
- Google Cloud provider `~> 6.0`, Terraform `>= 1.7`

## Getting started

One-time GCP setup lives in [`docs/bootstrap.md`](docs/bootstrap.md). Once bootstrap is done, all `plan` / `apply` / `destroy` happens through the workflows in [`.github/workflows/`](.github/workflows/) - triggered by PRs (plan), merges to `main` (apply, gated by the `production` environment reviewer), and manual dispatch (destroy).

## Cost and lifecycle

Full apply -> demo -> destroy cycle typically completes in under 15 minutes and costs cents. GKE control plane (~$0.10/hr for zonal) dominates.

## Follow-ups (v2 backlog)

- Scope deploy service account from `roles/owner` down to per-service permissions
- Disable the default Compute Engine service account editor grant (auto-created by Google)
- Add `tflint` + `trivy` to CI
- Restrict cluster endpoint public access CIDRs
- Pre-commit hooks
- Autopilot mode variant as a parallel narrative ("same platform, managed mode")
