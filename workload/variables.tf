variable "ovh_endpoint" {
  description = "OVHcloud API endpoint."
  type        = string
  default     = "ovh-eu"
}

variable "service_name" {
  description = "ID of the team's OVHcloud Public Cloud project."
  type        = string
}

# --- Where ../core keeps its state ---------------------------

variable "core_state_bucket" {
  description = "State bucket of the core config."
  type        = string
}

variable "core_state_key" {
  description = "State file key of the core config."
  type        = string
  default     = "achrona/core.tfstate"
}

variable "state_region" {
  description = "S3 region of the state bucket."
  type        = string
}

variable "state_endpoint" {
  description = "S3 endpoint of the state bucket."
  type        = string
}

variable "ancient_oracle_tag" {
  description = "Tag of the Ancient Oracle's image in the team's registry (<host>/realm/ancient-oracle)."
  type        = string
  default     = "1.0.0"
}

# --- Ingress -------------------------------------------------

variable "ingress_domain" {
  description = "Domain of the ingress host names (chamber.<domain>, grimoire.<domain>, ...). Not in any DNS: teams add `terraform output -raw hosts` to their /etc/hosts. .test is reserved for exactly this (RFC 6761)."
  type        = string
  default     = "achrona.test"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.ingress_domain))
    error_message = "ingress_domain must be a lowercase domain name with at least one dot, like achrona.test."
  }
}
