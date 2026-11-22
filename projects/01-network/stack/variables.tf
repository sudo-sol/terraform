variable "name" {
  description = "Short prefix for resource names in this deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,24}$", var.name))
    error_message = "Use up to 25 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "availability_zones" {
  description = "Two distinct Availability Zones in the provider region. List order determines subnet numbering."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Choose two distinct Availability Zones."
  }
}

variable "vpc_cidrs" {
  description = "Non-overlapping IPv4 CIDRs for the two spokes, shared services, and egress VPCs."
  type = object({
    spoke_a = string
    spoke_b = string
    shared  = string
    egress  = string
  })

  validation {
    condition = alltrue([
      for cidr in values(var.vpc_cidrs) :
      can(regex("^[0-9.]+/(1[6-9]|2[0-4])$", cidr)) && try(split("/", cidr)[0] == cidrhost(cidr, 0), false)
    ])
    error_message = "Each VPC needs a canonical IPv4 network with a /16 to /24 prefix."
  }

  validation {
    condition = alltrue(flatten([
      for source, source_cidr in var.vpc_cidrs : [
        for destination, destination_cidr in var.vpc_cidrs :
        try(cidrhost("${cidrhost(destination_cidr, 0)}/${split("/", source_cidr)[1]}", 0) != cidrhost(source_cidr, 0), true)
        if source != destination
      ]
    ]))
    error_message = "VPC CIDRs must not overlap."
  }
}

variable "private_zone_name" {
  description = "Private Route 53 zone associated with spoke A and shared services."
  type        = string
}

variable "private_records" {
  description = "IPv4 A records keyed by relative name. Supply addresses of services you own."
  type        = map(list(string))
  default     = {}
}

variable "resolver" {
  description = "Optional inbound and outbound Resolver endpoints. Outbound targets are DNS servers reachable in spoke B."
  type = object({
    forward_domain = string
    target_ips     = set(string)
  })
  default = null

  validation {
    condition = var.resolver == null ? true : (
      trimsuffix(lower(var.resolver.forward_domain), ".") != trimsuffix(lower(var.private_zone_name), ".") &&
      length(var.resolver.target_ips) >= 1 && length(var.resolver.target_ips) <= 6 &&
      alltrue([for ip in var.resolver.target_ips : can(cidrnetmask("${ip}/32"))])
    )
    error_message = "Use a forwarding domain distinct from the private zone and supply one to six IPv4 DNS targets."
  }
}

variable "allow_spoke_to_spoke" {
  description = "Allow direct routing between the workload spokes. Security groups still control access."
  type        = bool
  default     = false
}

variable "firewall" {
  description = "Enable Network Firewall when set. Allowed domains are exact TLS SNI names on TCP port 443."
  type = object({
    allowed_tls_domains = set(string)
    log_retention_days  = optional(number, 14)
  })
  default = null

  validation {
    condition = var.firewall == null ? true : (
      length(var.firewall.allowed_tls_domains) > 0 && length(var.firewall.allowed_tls_domains) <= 100 &&
      alltrue([
        for domain in var.firewall.allowed_tls_domains :
        length(domain) <= 253 && can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", domain))
      ])
    )
    error_message = "Supply one to 100 exact DNS names without wildcards, trailing dots, or URL syntax."
  }
}
