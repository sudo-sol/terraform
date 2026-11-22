mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-west-2" } }
  mock_data "aws_prefix_list" { defaults = { id = "pl-0123456789abcdef0" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  vpc_name                   = "vpc-regression"
  tags                       = {}
  cidr_block                 = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].cidr_block
  enable_dns_hostnames       = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].enable_dns_hostnames
  enable_dns_support         = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].enable_dns_support
  enable_flow_logs           = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].enable_flow_logs
  flow_logs_destination_type = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].flow_logs_destination_type
  flow_logs_log_group_name   = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].flow_logs_log_group_name
  flow_logs_traffic_type     = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].flow_logs_traffic_type
  flow_logs_retention_days   = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].flow_logs_retention_days
  vpc_subnets                = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].vpc_subnets
  internet_gateway           = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].internet_gateway
  nat_gateway                = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].nat_gateway
  route_tables               = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].route_tables
  security_groups            = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].security_groups
}

run "all_ingress_and_egress_cidrs" {
  command = plan
  module { source = "../../modules/aws/vpc" }
  variables {
    security_groups = {
      for name, sg in yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc["vpc-ecs-demo"].security_groups : name => merge(sg, {
        ingress_rules = [for rule in sg.ingress_rules : merge(rule, { cidr_blocks = ["10.42.0.0/24", "10.42.1.0/24", "10.42.1.0/24"] })]
        egress_rules  = [for rule in sg.egress_rules : merge(rule, { cidr_blocks = ["10.42.0.0/24", "10.42.1.0/24", "10.42.1.0/24"] })]
      })
    }
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ingress) == 6 && toset([for rule in aws_vpc_security_group_ingress_rule.ingress : rule.cidr_ipv4]) == toset(["10.42.0.0/24", "10.42.1.0/24"])
    error_message = "Every distinct ingress CIDR must have a rule; duplicates must not create duplicate AWS rules."
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.egress) == 6 && toset([for rule in aws_vpc_security_group_egress_rule.egress : rule.cidr_ipv4]) == toset(["10.42.0.0/24", "10.42.1.0/24"])
    error_message = "Every distinct egress CIDR must have a rule; duplicates must not create duplicate AWS rules."
  }
  assert {
    condition     = aws_flow_log.flow_logs[0].log_destination_type == "cloud-watch-logs" && length(aws_cloudwatch_log_group.flow_logs) == 1 && length(aws_iam_role.flow_logs) == 1
    error_message = "Enabled flow logs must have a CloudWatch destination and delivery role."
  }
}

run "reject_unsupported_s3" {
  command = plan
  module { source = "../../modules/aws/vpc" }
  variables { flow_logs_destination_type = "S3" }
  expect_failures = [var.flow_logs_destination_type]
}

run "flow_logs_disabled" {
  command = plan
  module { source = "../../modules/aws/vpc" }
  variables { enable_flow_logs = false }
  assert {
    condition     = length(aws_flow_log.flow_logs) == 0 && length(aws_cloudwatch_log_group.flow_logs) == 0 && length(aws_iam_role.flow_logs) == 0
    error_message = "Disabled flow logging must not create logging resources."
  }
}
