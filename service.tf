# The Cloud Run service
resource "google_cloud_run_v2_service" "my_service" {
  name     = local.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      dynamic "env" {
        for_each = local.envs
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = toset(local.secret_keys)
        content {
          name  = env.key
          # attach the latest version for each secret
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.my_service[env.key].secret_id
              version = "latest"
            }
          }
        }
      }
    }
    service_account = google_service_account.my_service.email

  }
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [google_project_service.run, google_project_iam_binding.my_service ]
}

output "my_service_url" {
  value = google_cloud_run_v2_service.my_service.uri
}

# Set service public
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}


resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_v2_service.my_service.location
  project  = google_cloud_run_v2_service.my_service.project
  service  = google_cloud_run_v2_service.my_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_v2_service.my_service]
}
