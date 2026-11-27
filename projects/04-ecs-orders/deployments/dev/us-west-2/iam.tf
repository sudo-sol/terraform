locals {
  task_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = { StringEquals = { "aws:SourceAccount" = var.account_id } }
    }]
  })
}

resource "aws_iam_role" "execution" {
  for_each           = toset(["service", "migration"])
  name               = "${local.name}-${each.key}-execution"
  assume_role_policy = local.task_trust
}

resource "aws_iam_role_policy_attachment" "execution" {
  for_each   = aws_iam_role.execution
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "migration_secret" {
  role = aws_iam_role.execution["migration"].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_db_instance.orders.master_user_secret[0].secret_arn }]
  })
}

resource "aws_iam_role" "api" {
  name               = "${local.name}-api"
  assume_role_policy = local.task_trust
}

resource "aws_iam_role_policy" "db_login" {
  role = aws_iam_role.api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:aws:rds-db:us-west-2:${var.account_id}:dbuser:${aws_db_instance.orders.resource_id}/orders_api"
    }]
  })
}
