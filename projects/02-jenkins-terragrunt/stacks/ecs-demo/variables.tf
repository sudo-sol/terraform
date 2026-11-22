## VPC Parameters
## ---------------------------------------------------------------------------

variable "vpc" {
  description = "A configuration map defining VPCs, subnets, gateways, route tables, and security groups."
  type = map(object({
    cidr_block                 = string
    enable_dns_hostnames       = bool
    enable_dns_support         = bool
    enable_flow_logs           = bool
    flow_logs_destination_type = string
    flow_logs_log_group_name   = string
    flow_logs_traffic_type     = string
    flow_logs_retention_days   = number

    vpc_subnets = object({
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

    internet_gateway = object({
      name    = string
      enabled = bool
    })

    nat_gateway = object({
      count       = number
      strategy    = string
      elastic_ips = list(string)
    })

    route_tables = map(object({
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

    security_groups = map(object({
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
  }))
}

## ECS Parameters
## ---------------------------------------------------------------------------

variable "ecs" {
  description = "A configuration map defining ECS clusters, Fargate services, ALBs, and autoscaling rules."
  type = map(object({
    ecr_repo_url               = string
    flow_logs_destination_type = string
    flow_logs_log_group_name   = string
    flow_logs_traffic_type     = string
    flow_logs_retention_days   = number

    capacity_providers = list(object({
      name   = string
      weight = number
      base   = number
    }))

    service = object({
      name                              = string
      container_name                    = string
      container_port                    = number
      cpu                               = number
      memory                            = number
      desired_count                     = number
      health_check_grace_period_seconds = number
    })

    alb = object({
      name                          = string
      internal                      = bool
      listener_port                 = number
      health_check_path             = string
      health_check_interval_seconds = number
      health_check_timeout_seconds  = number
      healthy_threshold             = number
      unhealthy_threshold           = number
      deregistration_delay_seconds  = number
    })

    autoscaling = object({
      min_capacity               = number
      max_capacity               = number
      scale_in_cooldown_seconds  = number
      scale_out_cooldown_seconds = number
      metrics = list(object({
        type         = string
        target_value = number
      }))
    })

  }))
}



## Tagging Parameters
## ---------------------------------------------------------------------------

variable "environment" {
  type = string
}

variable "project_version" {
  type = string
}

variable "project_name" {
  type = string
}

variable "managed_by" {
  type = string
}
