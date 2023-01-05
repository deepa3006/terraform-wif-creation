# Setup backend
terraform {
  backend "gcs" {
    bucket = "terraform-wif-example"
    # Bucket folder name
    prefix = "dev"
  }
}

# Setup provider
provider "google" {
  project = "utility-cumulus-372111"
  region  = "us-central1"
  zone    = "us-central1"
}

# resource "google_project_service" "project_required_services" {
#   for_each = toset([
#     "iam",
#     "iamcredentials",
#     "identitytoolkit",
#     "serviceusage"
#   ])
#   project = "utility-cumulus-372111"
#   service = "${each.value}.googleapis.com"
#   # (Optional) If true, services that are enabled and which depend on this service should also be disabled when this service is destroyed.
#   # If false or unset, an error will be generated if any enabled services depend on this service when destroying it.
#   disable_dependent_services = true
# }

resource "google_iam_workload_identity_pool" "wif_pool" {
  project                   = "utility-cumulus-372111"
  provider                  = google-beta
  workload_identity_pool_id = "github-pool"
  display_name              = "Github Identity Pool"
  description               = "Identity pool for Github Actions"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "wif_provider" {
  depends_on = [
    google_iam_workload_identity_pool.wif_pool
  ]
  provider                           = google-beta
  project                            = "utility-cumulus-372111"
  workload_identity_pool_id          = google_iam_workload_identity_pool.wif_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "Github Identity Pool Provider"
  description                        = "Identity pool provider for Github Actions."
  attribute_condition                = "attribute.repository in ['deepa3006/terraform-wif']"
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.ref_type"         = "assertion.ref_type"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "wif_service_account" {
  project      = "utility-cumulus-372111"
  account_id   = "github-actions"
  display_name = "Github Actions CICD Service Account"
  description  = "Service account used for Github Actions from repository \"deepa3006/terraform-wif\""
}

data "google_iam_policy" "wif_service_account_policy" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.wif_pool.name}/attribute.ref_type/branch",
    ]
  }
}

resource "google_service_account_iam_policy" "wif_iam_policy_binding" {
  service_account_id = google_service_account.wif_service_account.name
  policy_data        = data.google_iam_policy.wif_service_account_policy.policy_data
}