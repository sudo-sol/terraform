variable "vpc_name" {
  description = "The name of the VPC (extracted from the configuration map key)"
  type        = string
}

variable "cidr_block" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC"
  type        = bool
}

variable "enable_dns_support" {
  description = "A boolean flag to enable/disable DNS support in the VPC"
  type        = bool
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
}

variable "flow_logs_destination_type" {
  description = "Flow-log destination. This example supports CLOUD_WATCH_LOGS only."
  type        = string

  validation {
    condition     = var.flow_logs_destination_type == "CLOUD_WATCH_LOGS"
    error_message = "Only CLOUD_WATCH_LOGS is supported; S3 flow-log delivery is not implemented."
  }
}

variable "flow_logs_log_group_name" {
  description = "The name of the CloudWatch log group where flow logs will be sent"
  type        = string
}

variable "flow_logs_traffic_type" {
  description = "The type of traffic to log (e.g., ALL, ACCEPT, REJECT)"
  type        = string
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain the logs"
  type        = number
}

variable "vpc_subnets" {
  description = "Configuration block for all public and private subnets within this VPC"
  type = object({
    public = list(object({
      name              = string
      cidr              = string
      availability_zone = string
    }))
    private = list(object({
      name              = string
      cidr              = string
      availability_zone = string
    }))
  })
}

variable "internet_gateway" {
  description = "Internet Gateway deployment configuration"
  type = object({
    name    = string
    enabled = bool
  })
}

variable "nat_gateway" {
  description = "NAT Gateway scaling configuration"
  type = object({
    count       = number
    strategy    = string
    elastic_ips = list(string)
  })
}

variable "route_tables" {
  description = "Map of route tables and their corresponding routes and subnet associations"
  type = map(object({
    name = string
    routes = list(object({
      destination_cidr_block = string
      gateway_id             = optional(string)
      nat_gateway_id         = optional(string)
      description            = string
    }))
    subnet_associations = list(string)
    tags                = map(string)
  }))
}

variable "security_groups" {
  description = "Map of security groups along with their ingress and egress rule sets"
  type = map(object({
    name        = string
    description = string
    ingress_rules = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress_rules = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))
}

variable "tags" {
  description = "A map of tags to apply to the VPC and its resources"
  type        = map(string)
}
