// defines the secret
resource "google_secret_manager_secret" "my_service" {

  # loop over all the secrets we need to have
  for_each  = toset(local.secret_keys)

  secret_id = each.key

  replication {
    automatic = true
  }

  depends_on = [google_project_service.secretmanager]
}
