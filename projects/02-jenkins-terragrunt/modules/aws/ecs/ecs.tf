## ECS Cluster definitions

resource "aws_cloudwatch_log_group" "ecs" {
  name              = var.log_group_name
  retention_in_days = var.log_retention
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.cluster_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "cp" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [for cp in var.capacity_providers : cp.name]

  dynamic "default_capacity_provider_strategy" {
    for_each = local.fargate_strategies
    content {
      capacity_provider = default_capacity_provider_strategy.value["name"]
      weight            = default_capacity_provider_strategy.value["weight"]
      base              = default_capacity_provider_strategy.value["base"]
    }
  }
}

## Task definition and Service definitions

resource "aws_ecs_task_definition" "task_def" {
  family                   = var.service.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.service.cpu
  memory                   = var.service.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(local.container_definition)

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-task-definition"
  })
}

resource "aws_ecs_service" "service" {
  name                              = var.service.name
  cluster                           = aws_ecs_cluster.cluster.id
  task_definition                   = aws_ecs_task_definition.task_def.arn
  desired_count                     = var.service.desired_count
  health_check_grace_period_seconds = var.service.health_check_grace_period_seconds

  # Overridden dynamically by capacity provider logic configurations
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = local.fargate_strategies["FARGATE"]["weight"]
    base              = local.fargate_strategies["FARGATE"]["base"]
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = local.fargate_strategies["FARGATE_SPOT"]["weight"]
    base              = local.fargate_strategies["FARGATE_SPOT"]["base"]
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.app_security_group]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_alb.arn
    container_name   = var.service.container_name
    container_port   = var.service.container_port
  }

  lifecycle {
    ignore_changes = [desired_count] # Avoid state drift conflicts with Auto Scaling policies
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.cp,
    aws_iam_role_policy_attachment.execution,
    aws_cloudwatch_log_group.ecs,
  ]


  tags = merge(var.tags, {
    Name = "${var.cluster_name}-service"
  })
}
