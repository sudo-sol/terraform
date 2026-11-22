variable "account_id" {
  description = "AWS account ID the network provider is allowed to use."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "target" {
  description = "Deployment target, dev in us-west-2 or prod in us-east-1."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.target)
    error_message = "target must be dev or prod."
  }
}

variable "network" {
  description = "Topology, DNS settings, and prod firewall configuration for the selected target."
  type = object({
    name               = string
    availability_zones = list(string)
    vpc_cidrs = object({
      spoke_a = string
      spoke_b = string
      shared  = string
      egress  = string
    })
    private_zone_name = string
    private_records   = optional(map(list(string)), {})
    resolver = optional(object({
      forward_domain = string
      target_ips     = set(string)
    }))
    firewall = optional(object({
      allowed_tls_domains = set(string)
      log_retention_days  = optional(number, 14)
    }))
  })

  validation {
    condition     = (var.target == "prod") == (var.network.firewall != null)
    error_message = "Configure network.firewall for prod and omit it for dev."
  }
}
