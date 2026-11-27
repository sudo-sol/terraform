variable "migration_digest" {
  description = "ECR digest of the image to run for the next schema migration."
  type        = string
  default     = null
  validation {
    condition     = var.migration_digest == null || can(regex("^sha256:[a-f0-9]{64}$", var.migration_digest))
    error_message = "Supply an immutable sha256 image digest."
  }
}

variable "service_digest" {
  description = "ECR digest of the migrated release to serve, or null for infrastructure only."
  type        = string
  default     = null
  validation {
    condition     = var.service_digest == null || can(regex("^sha256:[a-f0-9]{64}$", var.service_digest))
    error_message = "Supply an immutable sha256 image digest."
  }
}

module "ecr" {
  source           = "../../../../../modules/aws/ecr"
  ecr_repositories = [{ name = local.name, images_to_keep = 10, scan_on_push = true }]
  environment      = "dev"
  project_name     = "04-ecs-orders"
  project_version  = "example"
  managed_by       = "terraform"
}

resource "aws_ecs_cluster" "orders" { name = local.name }

locals {
  db_env = {
    PGHOST        = aws_db_instance.orders.address
    PGDATABASE    = "orders"
    PGSSLMODE     = "verify-full"
    PGSSLROOTCERT = "/app/global-bundle.pem"
  }
  components = {
    web = {
      digest  = var.service_digest
      command = ["gunicorn", "--bind", "0.0.0.0:8080", "web:app"]
      env     = { API_URL = "http://${aws_lb.service["api"].dns_name}" }
    }
    api = {
      digest  = var.service_digest
      command = ["gunicorn", "--bind", "0.0.0.0:8080", "api:app"]
      env     = merge(local.db_env, { PGUSER = "orders_api", DB_IAM = "true" })
    }
    migration = {
      digest  = var.migration_digest
      command = ["python", "migrate.py"]
      env     = merge(local.db_env, { PGUSER = aws_db_instance.orders.username })
    }
  }
}

resource "aws_cloudwatch_log_group" "component" {
  for_each          = local.components
  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "component" {
  for_each                 = { for key, component in local.components : key => component if component.digest != null }
  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution[each.key == "migration" ? "migration" : "service"].arn
  task_role_arn            = each.key == "api" ? aws_iam_role.api.arn : null

  container_definitions = jsonencode([{
    name         = each.key
    image        = "${one(module.ecr.ecr_repository_uris)}@${each.value.digest}"
    essential    = true
    command      = each.value.command
    portMappings = each.key == "migration" ? [] : [{ containerPort = 8080, protocol = "tcp" }]
    environment  = [for key, val in each.value.env : { name = key, value = val }]
    secrets = each.key == "migration" ? [{
      name = "PGPASSWORD", valueFrom = "${aws_db_instance.orders.master_user_secret[0].secret_arn}:password::"
    }] : []
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.component[each.key].name
        awslogs-region        = "us-west-2"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "tier" {
  for_each                          = var.service_digest == null ? toset([]) : local.tiers
  name                              = each.key
  cluster                           = aws_ecs_cluster.orders.id
  task_definition                   = aws_ecs_task_definition.component[each.key].arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  wait_for_steady_state             = true
  health_check_grace_period_seconds = 60
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = module.network.private_subnets
    security_groups  = [aws_security_group.tier[each.key].id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.service[each.key].arn
    container_name   = each.key
    container_port   = 8080
  }
  depends_on = [aws_lb_listener.service, aws_iam_role_policy_attachment.execution, aws_iam_role_policy.db_login, aws_vpc_security_group_ingress_rule.path, aws_vpc_security_group_egress_rule.path, aws_vpc_security_group_egress_rule.https]
}

output "repository" { value = one(module.ecr.ecr_repository_uris) }
output "cluster" { value = aws_ecs_cluster.orders.name }
output "web_url" { value = "http://${aws_lb.service["web"].dns_name}" }
output "migration_task" { value = try(aws_ecs_task_definition.component["migration"].arn, null) }
output "migration_network" {
  value = { awsvpcConfiguration = {
    subnets = module.network.private_subnets, securityGroups = [aws_security_group.tier["api"].id], assignPublicIp = "DISABLED"
  } }
}
