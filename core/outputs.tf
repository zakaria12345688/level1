# Read by the workload/ config (terraform_remote_state) to find the cluster.
output "kube_id" {
  description = "ID of the Managed Kubernetes cluster."
  value       = ovh_cloud_project_kube.this.id
}

# Read by the workload/ config to pull images, and by whoever pushes them.
output "registry_url" {
  description = "URL of the team's container registry (Harbor). Images: <host>/realm/<image>:<tag>."
  value       = ovh_cloud_project_containerregistry.realm.url
}

output "registry_user" {
  description = "Registry user (docker login)."
  value       = ovh_cloud_project_containerregistry_user.realm.user
}

output "registry_password" {
  description = "Registry password: terraform output -raw registry_password"
  value       = ovh_cloud_project_containerregistry_user.realm.password
  sensitive   = true
}
output "scrolls_s3_access_key" {
  description = "S3 access key of the scrolls app user."
  value       = ovh_cloud_project_user_s3_credential.scrolls_app.access_key_id
  sensitive   = true
}

output "scrolls_s3_secret_key" {
  description = "S3 secret key of the scrolls app user."
  value       = ovh_cloud_project_user_s3_credential.scrolls_app.secret_access_key
  sensitive   = true
}