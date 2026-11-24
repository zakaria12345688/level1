locals {
  tags = {
    environment = "hack-the-future"
    team        = var.team_name
    managed-by  = "terraform"
  }

  # Bucket names are shared across all OVHcloud customers in a region,
  # so include part of the project ID to keep them unique.
  bucket_name = "${var.name_prefix}-${substr(var.service_name, 0, 8)}-scrolls"
}
