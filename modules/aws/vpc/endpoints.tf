## VPC Endpoint definitions

## ECR API Endpoint (Required for GetAuthorizationToken authentication checks)
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_ecs_endpoints ? 1 : 0

  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.security["endpoint_sg"].id] # Allows ECS Tasks to hit the endpoint
  subnet_ids          = [for _, sub in aws_subnet.private : sub.id]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-ecr-api-vpce"
  })
}

## ECR DKR Endpoint (Required for the actual physical container layer downloading)
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_ecs_endpoints ? 1 : 0

  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.security["endpoint_sg"].id]
  subnet_ids          = [for _, sub in aws_subnet.private : sub.id]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-ecr-dkr-vpce"
  })
}

## CloudWatch Logs Endpoint (Required so tasks can push their log outputs)
resource "aws_vpc_endpoint" "logs" {
  count = var.enable_ecs_endpoints ? 1 : 0

  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.security["endpoint_sg"].id]
  subnet_ids          = [for _, sub in aws_subnet.private : sub.id]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-logs-vpce"
  })
}

## Amazon S3 Gateway Endpoint (ECR stores its image layers in an internal AWS S3 bucket)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_ecs_endpoints ? 1 : 0

  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for _, rt in aws_route_table.route_table : rt.id]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-s3-vpce"
  })
}

## Allows the ECS task to communicate securely with S3
resource "aws_vpc_security_group_egress_rule" "app_to_s3_gateway" {
  count = var.enable_ecs_endpoints ? 1 : 0

  security_group_id = aws_security_group.security["app_sg"].id
  description       = "Allow ECS tasks to reach the Amazon S3 Gateway Endpoint for image downloads"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  prefix_list_id = data.aws_prefix_list.s3[0].id
}
