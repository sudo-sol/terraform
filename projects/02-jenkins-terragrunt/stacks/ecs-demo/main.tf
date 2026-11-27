module "vpc" {
  source   = "../../../../modules/aws/vpc"
  for_each = local.vpc_configs

  enable_ecs_endpoints = true

  ## Individual root attributes
  vpc_name                   = each.value["vpc_name"]
  cidr_block                 = each.value["cidr_block"]
  enable_dns_hostnames       = each.value["enable_dns_hostnames"]
  enable_dns_support         = each.value["enable_dns_support"]
  enable_flow_logs           = each.value["enable_flow_logs"]
  flow_logs_destination_type = each.value["flow_logs_destination_type"]
  flow_logs_log_group_name   = each.value["flow_logs_log_group_name"]
  flow_logs_traffic_type     = each.value["flow_logs_traffic_type"]
  flow_logs_retention_days   = each.value["flow_logs_retention_days"]

  ## Passing complex structures directly to the module variables
  vpc_subnets      = each.value["subnets"]
  internet_gateway = each.value["internet_gateway"]
  nat_gateway      = each.value["nat_gateway"]
  route_tables     = each.value["route_tables"]
  security_groups  = each.value["security_groups"]

  ## Tagging parameters
  tags = local.tags
}

module "ecs" {
  source   = "../../modules/aws/ecs"
  for_each = local.ecs_configs

  ## ECS Attributes
  cluster_name       = each.value["cluster_name"]
  ecr_repo_url       = each.value["ecr_repo_url"]
  capacity_providers = each.value["capacity_providers"]
  service            = each.value["service"]
  alb                = each.value["alb"]
  autoscaling        = each.value["autoscaling"]
  log_group_name     = each.value["log_group_name"]
  log_retention      = each.value["log_retention"]

  ## Dependencies from the existing VPC module defined above
  vpc_id             = one(values(module.vpc)).vpc_id
  public_subnets     = values(one(values(module.vpc)).public_subnet_ids)
  private_subnets    = values(one(values(module.vpc)).private_subnet_ids)
  alb_security_group = one(values(module.vpc)).security_group_ids["alb_sg"]
  app_security_group = one(values(module.vpc)).security_group_ids["app_sg"]

  ## Tagging parameters
  tags = local.tags
}
