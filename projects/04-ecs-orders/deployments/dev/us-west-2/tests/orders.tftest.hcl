mock_provider "aws" {
  mock_resource "aws_db_instance" {
    override_during = plan
    defaults = {
      address            = "orders.example.invalid"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-west-2:000000000000:secret:sample" }]
    }
  }
  mock_resource "aws_lb" {
    override_during = plan
    defaults        = { dns_name = "sample.elb.example.invalid", arn = "arn:aws:elasticloadbalancing:us-west-2:000000000000:loadbalancer/app/example/1234567890123456" }
  }
  mock_resource "aws_ecr_repository" {
    override_during = plan
    defaults        = { repository_url = "000000000000.dkr.ecr.us-west-2.amazonaws.com/ecs-orders-dev" }
  }
}

run "bootstrap_without_images" {
  command = plan
  assert {
    condition     = length(aws_ecs_service.tier) == 0 && length(aws_ecs_task_definition.component) == 0
    error_message = "Bootstrap must create the registry before anything references an image."
  }
}

run "migration_only" {
  command = plan
  variables { migration_digest = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
  assert {
    condition     = keys(aws_ecs_task_definition.component) == ["migration"] && length(aws_ecs_service.tier) == 0
    error_message = "The migration must be runnable before the initial service rollout."
  }
  assert {
    condition     = one(jsondecode(aws_ecs_task_definition.component["migration"].container_definitions)).secrets[0].name == "PGPASSWORD"
    error_message = "Only the migration container should receive the RDS-managed password."
  }
}

run "serve_release" {
  command = plan
  variables { service_digest = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
  assert {
    condition     = keys(aws_ecs_service.tier) == ["api", "web"] && alltrue([for svc in aws_ecs_service.tier : svc.launch_type == "FARGATE" && !svc.network_configuration[0].assign_public_ip])
    error_message = "Both tiers must run on private Fargate tasks."
  }
  assert {
    condition = alltrue([for tier in local.tiers :
      length(one(jsondecode(aws_ecs_task_definition.component[tier].container_definitions)).secrets) == 0 &&
      endswith(one(jsondecode(aws_ecs_task_definition.component[tier].container_definitions)).image, "@${var.service_digest}")
    ])
    error_message = "Serving containers must use the chosen image digest and receive no admin secret."
  }
  assert {
    condition     = aws_lb.service["api"].internal && !aws_lb.service["web"].internal && alltrue([for tg in aws_lb_target_group.service : tg.target_type == "ip"]) && aws_vpc_security_group_ingress_rule.operator.cidr_ipv4 == var.operator_cidr
    error_message = "Only the operator-facing web ALB should accept public traffic."
  }
  assert {
    condition     = !aws_db_instance.orders.publicly_accessible && aws_db_instance.orders.storage_encrypted && aws_db_instance.orders.manage_master_user_password && aws_db_instance.orders.iam_database_authentication_enabled && [for path in local.ingress_paths : path.source if path.destination == "db"] == ["api"]
    error_message = "The private, encrypted database should accept traffic from the API group only."
  }
}

run "reject_tag" {
  command = plan
  variables { service_digest = "latest" }
  expect_failures = [var.service_digest]
}
