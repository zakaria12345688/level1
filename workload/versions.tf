terraform {
  required_version = ">= 1.6.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Same state bucket as ../core, but its own state file, so the core config
  # never depends on the cluster API being reachable. Bucket, region and
  # endpoint come from backend.hcl:
  #   terraform init -backend-config=backend.hcl
  # S3 credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  # (the same ones as for ../core: ../state-credentials.env), and the
  # OVHcloud service account from ../ovh-credentials.env.
  #
  # No state locking is configured: never run two applies at the same time.
  backend "s3" {
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "ovh" {
  endpoint = var.ovh_endpoint
}

# Talks to the cluster created by ../core. The credentials come
# from the cluster itself, nothing to configure.
provider "helm" {
  kubernetes = {
    host                   = data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].host
    cluster_ca_certificate = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].cluster_ca_certificate)
    client_certificate     = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].client_certificate)
    client_key             = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].client_key)
  }
}

provider "kubernetes" {
  host                   = data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].host
  cluster_ca_certificate = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].cluster_ca_certificate)
  client_certificate     = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].client_certificate)
  client_key             = base64decode(data.ovh_cloud_project_kube.this.kubeconfig_attributes[0].client_key)
}
