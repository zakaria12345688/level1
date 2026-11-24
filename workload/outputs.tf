locals {
  ingress_ip    = try(data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].ip, null)
  ingress_hosts = [for h in ["chamber", "grimoire", "alertmanager", "magician"] : "${h}.${var.ingress_domain}"]
}

output "url" {
  description = "Where the chamber, the grimoire, Alertmanager and the magician are reachable (basic auth)."
  value       = local.ingress_ip == null ? "not ready yet: run terraform apply again in a minute" : "http://${local.ingress_ip}/"
}

output "hosts" {
  description = "The line for /etc/hosts (on Windows: C:/Windows/System32/drivers/etc/hosts): terraform output -raw hosts | sudo tee -a /etc/hosts"
  value       = local.ingress_ip == null ? "" : "${local.ingress_ip} ${join(" ", local.ingress_hosts)}\n"
}

output "urls" {
  description = "The services by name, once the hosts line is in place (basic auth)."
  value = {
    chamber      = "http://chamber.${var.ingress_domain}/"
    grimoire     = "git clone http://guild@grimoire.${var.ingress_domain}/realm.git"
    alertmanager = "http://alertmanager.${var.ingress_domain}/"
    magician     = "http://magician.${var.ingress_domain}/"
  }
}

output "username" {
  description = "Basic auth user for url."
  value       = local.ingress_user
}

output "password" {
  description = "Basic auth password for url: terraform output -raw password"
  value       = random_password.ingress.result
  sensitive   = true
}

output "mcp_url" {
  description = "The Ancient Oracle's MCP endpoint (Streamable HTTP, same basic auth as url)."
  value       = try("http://${data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].ip}/mcp", "not ready yet: run terraform apply again in a minute")
}
