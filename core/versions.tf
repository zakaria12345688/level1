terraform {
  required_version = ">= 1.6.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.0"
    }
  }

  # State lives in an OVHcloud Object Storage (S3-compatible) bucket in your
  # project. Bucket, key, region and endpoint come from backend.hcl:
  #   terraform init -backend-config=backend.hcl
  # Backends can't use variables, which is why these values are in a file.
  # S3 credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
  #
  # No state locking is configured: never run two applies at the same time.
  backend "s3" {
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

# Credentials are read from the environment:
#   OVH_CLIENT_ID / OVH_CLIENT_SECRET   (your team's OVHcloud service account: ../ovh-credentials.env)
provider "ovh" {
  endpoint = var.ovh_endpoint
}
