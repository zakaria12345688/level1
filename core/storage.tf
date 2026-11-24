# Private, versioned, encrypted bucket holding application data ("the scrolls").

resource "ovh_cloud_storage_object_bucket" "scrolls" {
  service_name = var.service_name
  region       = var.storage_region
  name         = local.bucket_name

  versioning = {
    status = "ENABLED"
  }

  encryption = {
    algorithm = "AES256"
  }

  tags = local.tags
}

resource "ovh_cloud_project_storage_object_bucket_lifecycle_configuration" "scrolls" {
  service_name   = var.service_name
  region_name    = var.storage_region
  container_name = ovh_cloud_storage_object_bucket.scrolls.name

  rules = [
    {
      id     = "expire-old-versions"
      status = "enabled"
      noncurrent_version_expiration = {
        noncurrent_days           = 30
        newer_noncurrent_versions = 5
      }
    },
    {
      id     = "abort-incomplete-uploads"
      status = "enabled"
      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }
    },
  ]
}
