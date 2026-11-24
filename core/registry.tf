# The team's container registry (OVHcloud Managed Private Registry, Harbor),
# where the realm's images live, among them the Ancient Oracle's
# (../workload/images/ancient-oracle). Images go to the Harbor project `realm`:
#   <registry_url without https://>/realm/<image>:<tag>
#
#   terraform output registry_url
#   terraform output registry_user
#   terraform output -raw registry_password

data "ovh_cloud_project_capabilities_containerregistry_filter" "registry" {
  service_name = var.service_name
  plan_name    = var.registry_plan
  region       = var.registry_region
}

resource "ovh_cloud_project_containerregistry" "realm" {
  service_name = var.service_name
  name         = "${var.name_prefix}-registry"
  region       = var.registry_region
  plan_id      = data.ovh_cloud_project_capabilities_containerregistry_filter.registry.id
}

# A Harbor user with admin rights on the registry: pushes images, and the
# cluster pulls with it (Secret realm-registry, ../workload/ancient.tf).
resource "ovh_cloud_project_containerregistry_user" "realm" {
  service_name = var.service_name
  registry_id  = ovh_cloud_project_containerregistry.realm.id
  login        = "scribe"
  email        = "scribe@${var.name_prefix}.example.com"
}
