# Bootstrap

One-time manual setup before the first `terraform init`. Everything here is prerequisite that Terraform cannot self-bootstrap (the state backend and CI auth themselves).

## Prerequisites

- `gcloud` CLI authenticated as your GCP account (`gcloud auth login`)
- `gh` CLI authenticated to GitHub (`gh auth login`)
- Terraform >= 1.7
- A GCP billing account active on your identity

## 1. Accept updated Terms of Service

If the Console shows "Some Terms of Service have been updated - Review updates", accept before running `gcloud services enable` (otherwise API calls return `TOS not accepted`).

## 2. Create project

```bash
export PROJECT_ID=dstepanov-gke-platform    # globally unique; add suffix if taken
export REPO=bibigon14/terraform-gke-platform
export REGION=us-west1

# Grab the first billing account you can see
export BILLING_ACCOUNT=$(gcloud billing accounts list \
  --format='value(name)' --limit=1 | sed 's|billingAccounts/||')

gcloud projects create $PROJECT_ID --name="Terraform GKE Platform"
gcloud billing projects link  $PROJECT_ID --billing-account=$BILLING_ACCOUNT
gcloud config   set project    $PROJECT_ID

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID \
  --format='value(projectNumber)')
```

## 3. Enable required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iamcredentials.googleapis.com \
  serviceusage.googleapis.com \
  storage.googleapis.com
```

## 4. Create GCS state bucket

```bash
export STATE_BUCKET=${PROJECT_ID}-tfstate

gcloud storage buckets create gs://$STATE_BUCKET \
  --location=$REGION \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update gs://$STATE_BUCKET --versioning
gcloud storage buckets update gs://$STATE_BUCKET --soft-delete-duration=7d
```

Note: GCS backend has built-in state locking via object generation numbers - no DynamoDB equivalent needed (one less bootstrap component vs the AWS/EKS repo).

## 5. Configure Workload Identity Federation for GitHub OIDC

```bash
export POOL_ID=github-actions
export PROVIDER_ID=github-provider

gcloud iam workload-identity-pools create $POOL_ID \
  --location=global \
  --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
  --location=global \
  --workload-identity-pool=$POOL_ID \
  --display-name="GitHub OIDC Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository == '${REPO}'"
```

The `attribute-condition` restricts token exchange to this specific repo - equivalent to the `sub` binding in the EKS OIDC trust policy.

## 6. Create deploy service account

```bash
export DEPLOY_SA=terraform-deploy
export DEPLOY_SA_EMAIL="${DEPLOY_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create $DEPLOY_SA \
  --display-name="Terraform GKE Platform deploy"

# Owner for demo simplicity; v2 scopes this down
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${DEPLOY_SA_EMAIL}" \
  --role="roles/owner"
```

## 7. Bind WIF principal to deploy SA

```bash
gcloud iam service-accounts add-iam-policy-binding $DEPLOY_SA_EMAIL \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${REPO}"
```

## 8. Set GitHub repo variables

```bash
export WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

gh variable set GCP_PROJECT_ID  --body="$PROJECT_ID"       --repo=$REPO
gh variable set GCP_REGION      --body="$REGION"           --repo=$REPO
gh variable set TF_STATE_BUCKET --body="$STATE_BUCKET"     --repo=$REPO
gh variable set TF_STATE_PREFIX --body="gke-platform"      --repo=$REPO
gh variable set WIF_PROVIDER    --body="$WIF_PROVIDER"     --repo=$REPO
gh variable set WIF_SA          --body="$DEPLOY_SA_EMAIL"  --repo=$REPO
```

## 9. Create production environment with required reviewer

Repo Settings -> Environments -> New environment `production`:

- Required reviewers: `bibigon14`
- Deployment branches: restrict to `main`

## 10. Verify

```bash
# Bucket exists and is versioned
gcloud storage buckets describe gs://$STATE_BUCKET \
  --format='value(versioning.enabled)'   # should print True

# WIF condition wired to this repo
gcloud iam workload-identity-pools providers describe $PROVIDER_ID \
  --location=global --workload-identity-pool=$POOL_ID \
  --format='value(attributeCondition)'

# Deploy SA has owner
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten='bindings[].members' \
  --filter="bindings.members:${DEPLOY_SA_EMAIL}" \
  --format='value(bindings.role)'

# Repo variables set
gh variable list --repo $REPO
```

If all four checks return expected values, you are ready for `terraform init` in the first PR.

## Rollback

If you need to start over completely:

```bash
gcloud projects delete $PROJECT_ID
```

Project deletion goes into a 30-day pending-delete window and cascades to all contained resources (bucket, service accounts, WIF pool). Billing account detaches automatically and survives.

## Troubleshooting

**OIDC token exchange fails with `PermissionDenied` on `sts.googleapis.com`**
Check Cloud Logging for the exact `assertion.*` claim values the token actually carried, then reconcile against the `attribute-condition` set in step 5. GitHub subject claim conventions can be customized per-org - if the exchange fails, that is usually the source (parallels the EKS repo lesson where the sub claim included org/repo IDs).

**`gcloud services enable` returns `TOS not accepted`**
Return to step 1 - the Console banner needs to be actioned even if you never see the API-focused TOS explicitly.
