# Least-privilege identity used by workloads on the cluster to access the
# scrolls bucket. It can read and write objects in that one bucket only.

resource "ovh_cloud_project_user" "scrolls_app" {
  service_name = var.service_name
  description  = "${var.name_prefix}-scrolls-app"
  role_names   = ["objectstore_operator"]
}

resource "ovh_cloud_project_user_s3_credential" "scrolls_app" {
  service_name = var.service_name
  user_id      = ovh_cloud_project_user.scrolls_app.id
}

resource "ovh_cloud_project_user_s3_policy" "scrolls_app" {
  service_name = var.service_name
  user_id      = ovh_cloud_project_user.scrolls_app.id

  policy = jsonencode({
    Statement = [
      {
        Sid    = "ScrollsReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListMultipartUploadParts",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          "arn:aws:s3:::${ovh_cloud_storage_object_bucket.scrolls.name}",
          "arn:aws:s3:::${ovh_cloud_storage_object_bucket.scrolls.name}/*",
        ]
      },
    ]
  })
}

# Tijdelijk: ghost user (administrator, buiten Terraform aangemaakt) opnemen in
# de state, zodat hij daarna via Git en de pipeline verwijderd kan worden.
resource "ovh_cloud_project_user" "debug_admin" {
  service_name = var.service_name
  description  = "debug-admin"
  role_names   = ["administrator"]
}

import {
  to = ovh_cloud_project_user.debug_admin
  id = "${var.service_name}/1014660"
}