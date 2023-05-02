terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.63"
    }
  }
}

provider "google" {
  project = local.project_id
  region = var.region
}

locals {
  project_id = var.project
  # the service account name my-service will use
  my_service_sa  = "serviceAccount:${google_service_account.my_service.email}"
  secret_keys = [
    "SECRET_1", "SECRET_2", "SECRET_3"
  ]
  envs = {
    ENV1 : "one"
    ENV2 : "two"
    ENV3 : "three"
  }

  service_name    = "my-service"
}