resource "random_password" "signing_key" {
  length  = 48
  special = false
}

resource "helm_release" "monitoring" {
  name      = "kube-monitoring"
  chart     = "${path.module}/charts/kube-monitoring"
  namespace = "observability"

  create_namespace = true
  wait             = true
  timeout          = 600

  set = [
    { name = "ingress.domain", value = var.ingress_domain },
  ]

  set_sensitive = [
    { name = "scrolls.s3AccessKey", value = data.terraform_remote_state.core.outputs.scrolls_s3_access_key },
    { name = "scrolls.s3SecretKey", value = data.terraform_remote_state.core.outputs.scrolls_s3_secret_key },
    { name = "scrolls.signingKey", value = random_password.signing_key.result },
  ]
}