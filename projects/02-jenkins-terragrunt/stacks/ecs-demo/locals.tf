locals {
  ## Normalize and flatten the complex nested VPC variable map
  vpc_configs = {
    for vpc_key, config in var.vpc : vpc_key => {
      vpc_name                   = vpc_key
      cidr_block                 = config.cidr_block
      enable_dns_hostnames       = config.enable_dns_hostnames
      enable_dns_support         = config.enable_dns_support
      enable_flow_logs           = config.enable_flow_logs
      flow_logs_destination_type = config.flow_logs_destination_type
      flow_logs_log_group_name   = config.flow_logs_log_group_name
      flow_logs_traffic_type     = coalesce(config.flow_logs_traffic_type, "ALL")
      flow_logs_retention_days   = coalesce(config.flow_logs_retention_days, 30)

      # Extracting child configurations cleanly
      subnets          = config.vpc_subnets
      internet_gateway = config.internet_gateway
      nat_gateway      = config.nat_gateway
      route_tables     = config.route_tables
      security_groups  = config.security_groups
    }
  }

  ## Normalize and flatten the complex nested ECS variable map
  ecs_configs = {
    for cluster_key, config in var.ecs : cluster_key => {
      cluster_name       = cluster_key
      ecr_repo_url       = config.ecr_repo_url
      capacity_providers = config.capacity_providers
      service            = config.service
      alb                = config.alb
      autoscaling        = config.autoscaling
      log_group_name     = config.flow_logs_log_group_name
      log_retention      = config.flow_logs_retention_days
    }
  }

  tags = {
    Environment = var.environment,
    Project     = var.project_name,
    Version     = var.project_version,
    ManagedBy   = var.managed_by
  }
}
