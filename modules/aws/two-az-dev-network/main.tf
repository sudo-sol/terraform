variable "name" { type = string }
variable "cidr" { type = string }
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(distinct(var.availability_zones)) == 2 && length(var.availability_zones) == 2
    error_message = "Choose two distinct Availability Zones."
  }
}

locals {
  subnets = {
    for tier_index, tier in ["public", "private"] : tier => [
      for index, zone in var.availability_zones : {
        name              = "${tier}-${index + 1}"
        availability_zone = zone
        cidr              = cidrsubnet(var.cidr, 4, 2 * tier_index + index)
      }
    ]
  }
}

module "vpc" {
  source = "../vpc"

  vpc_name                   = var.name
  cidr_block                 = var.cidr
  vpc_subnets                = local.subnets
  enable_dns_hostnames       = true
  enable_dns_support         = true
  enable_ecs_endpoints       = false
  enable_flow_logs           = false
  flow_logs_destination_type = "CLOUD_WATCH_LOGS"
  flow_logs_log_group_name   = "/vpc/${var.name}"
  flow_logs_traffic_type     = "ALL"
  flow_logs_retention_days   = 7
  internet_gateway           = { name = "${var.name}-igw", enabled = true }
  nat_gateway                = { count = 1, strategy = "single", elastic_ips = [] }
  security_groups            = {}
  tags                       = { Project = var.name }
  route_tables = {
    for tier, subnets in local.subnets : tier => {
      name                = "${var.name}-${tier}"
      tags                = {}
      subnet_associations = subnets[*].name
      routes = [{
        description            = "IPv4 default route"
        destination_cidr_block = "0.0.0.0/0"
        gateway_id             = tier == "public" ? "igw" : null
        nat_gateway_id         = tier == "private" ? "nat_single" : null
      }]
    }
  }
}

output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnets" { value = values(module.vpc.public_subnet_ids) }
output "private_subnets" { value = values(module.vpc.private_subnet_ids) }
