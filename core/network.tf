# Private network in the project's vRack. Nodes and load balancers live here.
# Its id is the regional OpenStack network ID, which is what the Kube API expects.

resource "ovh_cloud_network_private_vrack" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-net"
  vlan_id      = var.vlan_id
  region       = var.region
}

resource "ovh_cloud_network_private_vrack_subnet" "nodes" {
  service_name = var.service_name
  network_id   = ovh_cloud_network_private_vrack.this.id
  region       = var.region
  name         = "${var.name_prefix}-subnet"

  cidr = var.subnet_cidr

  # The gateway attaches a router interface to this subnet, which needs a gateway IP.
  # Left unset, the subnet is created without one and the gateway ends up in ERROR.
  gateway_ip = cidrhost(var.subnet_cidr, 1)
  allocation_pools = [{
    start = cidrhost(var.subnet_cidr, 10)
    end   = cidrhost(var.subnet_cidr, -2)
  }]
  dhcp_enabled = true
}

# Managed gateway (router + SNAT) for the private network.
resource "ovh_cloud_gateway" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-gateway"
  region       = var.region

  external_gateway = {
    enabled = true
    model   = upper(var.gateway_model)
  }

  subnet_ids = [ovh_cloud_network_private_vrack_subnet.nodes.id]
}
