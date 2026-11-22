locals {
  ## Format standard Fargate log driver execution structure
  log_driver = "awslogs"

  ## Clean mapping for capacity provider definitions
  fargate_strategies = {
    for cp in var.capacity_providers : cp.name => cp
  }

  ## Rendered Container Definition Payload Object mapped natively to string
  container_definition = [
    {
      name      = var.service.container_name
      image     = "${var.ecr_repo_url}:latest" # Assumes standard tag execution lifecycle tracking
      cpu       = var.service.cpu
      memory    = var.service.memory
      essential = true

      portMappings = [
        {
          containerPort = var.service.container_port
          hostPort      = var.service.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = local.log_driver
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = var.service.name
        }
      }
    }
  ]

  # Explicit mapping matrix for AWS Predefined Metric Types
  metric_mapping = {
    "cpu"    = "ECSServiceAverageCPUUtilization"
    "memory" = "ECSServiceAverageMemoryUtilization"
  }
}
