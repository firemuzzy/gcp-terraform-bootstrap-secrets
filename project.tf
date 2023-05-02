# enable iam for permissions
resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# enable cloud run
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# enable secrets manager
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Create a service account for my-service
resource "google_service_account" "my_service" {
  account_id   = "my-service"
  display_name = "My Service service account"
}

# Set permissions on service account
resource "google_project_iam_binding" "my_service" {
  project = var.project

  for_each = toset([
    "run.invoker",
    "secretmanager.secretAccessor"
  ])

  role       = "roles/${each.key}"
  members    = [local.my_service_sa]
  depends_on = [google_service_account.my_service]
}
