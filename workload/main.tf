# The cluster created by ../core. Its ID comes from that
# config's outputs, which this config reads from the state bucket.
data "terraform_remote_state" "core" {
  backend = "s3"

  config = {
    bucket = var.core_state_bucket
    key    = var.core_state_key
    region = var.state_region

    endpoints = {
      s3 = var.state_endpoint
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

data "ovh_cloud_project_kube" "this" {
  service_name = var.service_name
  kube_id      = data.terraform_remote_state.core.outputs.kube_id
}
