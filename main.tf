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

resource "google_project_service" "project_required_services" {
  for_each = toset([
    "iam",
    "iamcredentials",
    "identitytoolkit",
    "serviceusage"
  ])
  project = "utility-cumulus-372111"
  service = "${each.value}.googleapis.com"
  # (Optional) If true, services that are enabled and which depend on this service should also be disabled when this service is destroyed.
  # If false or unset, an error will be generated if any enabled services depend on this service when destroying it.
  disable_dependent_services = true
}

resource "google_iam_workload_identity_pool" "wif_pool1" {
  project                   = "utility-cumulus-372111"
  provider                  = google-beta
  workload_identity_pool_id = "github-pool1"
  display_name              = "Github Identity Pool1"
  description               = "Identity pool for Github Actions1"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "wif_provider1" {
  depends_on = [
    google_iam_workload_identity_pool.wif_pool1
  ]
  provider                           = google-beta
  project                            = "utility-cumulus-372111"
  workload_identity_pool_id          = google_iam_workload_identity_pool.wif_pool1.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider1"
  display_name                       = "Github Identity Pool Provider1"
  description                        = "Identity pool provider for Github Actions1."
  attribute_condition                = "attribute.repository in ['deepa3006/terraform-wif-creation']"
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

resource "google_service_account" "wif_service_account1" {
  project      = "utility-cumulus-372111"
  account_id   = "github-actions1"
  display_name = "Github Actions CICD Service Accoun1t"
  description  = "Service account used for Github Actions from repository \"deepa3006/terraform-wif-creation\""
}

data "google_iam_policy" "wif_service_account_policy" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.wif_pool1.name}/attribute.ref_type/branch",
    ]
    
  }
}

resource "google_service_account_iam_policy" "wif_iam_policy_binding" {
  service_account_id = google_service_account.wif_service_account1.name
  policy_data        = data.google_iam_policy.wif_service_account_policy.policy_data
}
