# The way in from outside: Traefik behind one OVHcloud Load Balancer, with
# basic auth on every route. The routes themselves are Ingresses in the
# kube-monitoring chart (templates/ingress.yaml).
#
#   terraform output url        # http://<load balancer IP>/
#   terraform output -raw password
#
# The Load Balancer is created by the cluster, not by Terraform: destroy this
# config (or at least this release) before ../core, or it is left behind.

locals {
  ingress_namespace = "traefik"
  ingress_user      = "guild"
}

resource "random_password" "ingress" {
  length  = 24
  special = false
}

resource "kubernetes_namespace_v1" "ingress" {
  metadata {
    name = local.ingress_namespace
  }
}

# Read by the basic-auth Middleware below. Lives here, not in the
# kube-monitoring chart, so reinstalling that chart never changes it.
resource "kubernetes_secret_v1" "ingress_auth" {
  metadata {
    name      = "guild-auth"
    namespace = kubernetes_namespace_v1.ingress.metadata[0].name
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = local.ingress_user
    password = random_password.ingress.result
  }
}

resource "helm_release" "ingress" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "42.2.0"
  namespace  = kubernetes_namespace_v1.ingress.metadata[0].name

  wait    = true
  timeout = 900

  values = [yamlencode({
    ingressClass = {
      enabled        = true
      isDefaultClass = true
      name           = "traefik"
    }

    providers = {
      # The Ingresses in other namespaces use the Middlewares defined here.
      kubernetesCRD = {
        allowCrossNamespace = true
      }
      kubernetesIngress = {
        publishedService = { enabled = true }
      }
    }

    # Plain HTTP only: there is no DNS name to get a certificate for.
    ports = {
      websecure = { expose = { default = false } }
    }

    service = {
      type = "LoadBalancer"
      annotations = {
        "loadbalancer.ovhcloud.com/flavor" = "small"
      }
    }

    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { cpu = "500m", memory = "256Mi" }
    }

    extraObjects = [
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata   = { name = "guild-auth", namespace = local.ingress_namespace }
        spec = {
          basicAuth = {
            secret       = kubernetes_secret_v1.ingress_auth.metadata[0].name
            realm        = "Achrona"
            removeHeader = true
          }
        }
      },
      # /magician -> /magician/, so the page's relative links resolve.
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata   = { name = "trailing-slash", namespace = local.ingress_namespace }
        spec = {
          redirectRegex = {
            regex       = "^(https?://[^/]+/[a-z-]+)$"
            replacement = "$${1}/"
            permanent   = true
          }
        }
      },
      # alertmanager.<domain>/ -> /alertmanager/ (Alertmanager runs under that prefix).
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata   = { name = "alertmanager-root", namespace = local.ingress_namespace }
        spec = {
          redirectRegex = {
            regex       = "^(https?://[^/]+)/?$"
            replacement = "$${1}/alertmanager/"
          }
        }
      },
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata   = { name = "strip-magician", namespace = local.ingress_namespace }
        spec = {
          stripPrefix = { prefixes = ["/magician"] }
        }
      },
    ]
  })]
}

data "kubernetes_service_v1" "ingress" {
  metadata {
    name      = helm_release.ingress.name
    namespace = helm_release.ingress.namespace
  }
}
