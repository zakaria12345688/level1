resource "ovh_cloud_project_kube" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-kube"
  region       = var.region
  plan         = var.kube_plan
  version      = var.kube_version

  update_policy   = "MINIMAL_DOWNTIME"
  kube_proxy_mode = "iptables"

  private_network_id = ovh_cloud_network_private_vrack.this.id
  nodes_subnet_id    = ovh_cloud_network_private_vrack_subnet.nodes.id

  private_network_configuration {
    default_vrack_gateway              = ""
    private_network_routing_as_default = false
  }

  depends_on = [ovh_cloud_gateway.this]
}

resource "ovh_cloud_project_kube_nodepool" "default" {
  service_name = var.service_name
  kube_id      = ovh_cloud_project_kube.this.id
  name         = "${var.name_prefix}-pool"
  flavor_name  = var.node_flavor

  autoscale      = true
  min_nodes      = var.node_min_count
  max_nodes      = var.node_max_count
  desired_nodes  = var.node_desired_count
  anti_affinity  = true
  monthly_billed = false

  template {
    metadata {
      annotations = {}
      finalizers  = []
      labels      = local.tags
    }
    spec {
      unschedulable = false
      taints        = []
    }
  }

  lifecycle {
    # The autoscaler owns the actual node count.
    ignore_changes = [desired_nodes]
  }
}

import {
  to = ovh_cloud_project_kube_nodepool.default
  id = "${var.service_name}/d2c8923d-f6ba-4223-b6aa-97316c581472/a1376202-de1f-4b72-acc6-531d105067c6"
}

# Tijdelijk: ghost pool opnemen in de state, zodat hij daarna via Git verwijderd kan worden.
resource "ovh_cloud_project_kube_nodepool" "hotfix" {
  service_name   = var.service_name
  kube_id        = ovh_cloud_project_kube.this.id
  name           = "hotfix-pool"
  flavor_name    = "b3-8"
  autoscale      = false
  desired_nodes  = 1
  min_nodes      = 1
  max_nodes      = 1
  anti_affinity  = false
  monthly_billed = false
}

import {
  to = ovh_cloud_project_kube_nodepool.hotfix
  id = "${var.service_name}/d2c8923d-f6ba-4223-b6aa-97316c581472/ade3b16a-dddd-46d9-849e-7e7e7e93e855"
}
resource "ovh_cloud_project_kube_iprestrictions" "this" {
  service_name = var.service_name
  kube_id      = ovh_cloud_project_kube.this.id
  ips          = []
}

import {
  to = ovh_cloud_project_kube_iprestrictions.this
  id = "${var.service_name}/d2c8923d-f6ba-4223-b6aa-97316c581472"
}