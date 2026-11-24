# The Ancient Oracle: the realm's Kubernetes MCP server (chart charts/ancient-oracle,
# image built from images/ancient-oracle and kept in the team's registry, ../core
# registry.tf). Reachable at <url>/mcp with the ingress's basic auth.
#
# To roll out a new image: build and push it with a new tag, set
# ancient_oracle_tag (terraform.tfvars or -var), bump the chart's version if
# you changed the chart, and terraform apply.

locals {
  ancient_namespace = "ancient"
  registry_host     = trimsuffix(replace(data.terraform_remote_state.core.outputs.registry_url, "/^https?:\\/\\//", ""), "/")
  registry_user     = data.terraform_remote_state.core.outputs.registry_user
  registry_password = data.terraform_remote_state.core.outputs.registry_password
}

resource "kubernetes_namespace_v1" "ancient" {
  metadata {
    name = local.ancient_namespace
  }
}

# Lets the cluster pull from the team's registry. Outside the chart, like the
# ingress's auth Secret.
resource "kubernetes_secret_v1" "registry" {
  metadata {
    name      = "realm-registry"
    namespace = kubernetes_namespace_v1.ancient.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.registry_host) = {
          username = local.registry_user
          password = local.registry_password
          auth     = base64encode("${local.registry_user}:${local.registry_password}")
        }
      }
    })
  }
}

resource "helm_release" "ancient_oracle" {
  name      = "ancient-oracle"
  chart     = "${path.module}/charts/ancient-oracle"
  namespace = kubernetes_namespace_v1.ancient.metadata[0].name

  wait    = true
  timeout = 600

  set = [
    { name = "image.repository", value = "${local.registry_host}/realm/ancient-oracle" },
    { name = "image.tag", value = var.ancient_oracle_tag },
    { name = "image.pullSecret", value = kubernetes_secret_v1.registry.metadata[0].name },
  ]
}
