locals {
  tiers = toset(["web", "api"])
  ingress_paths = {
    web_task = { source = "web_alb", destination = "web", port = 8080 }
    api_alb  = { source = "web", destination = "api_alb", port = 80 }
    api_task = { source = "api_alb", destination = "api", port = 8080 }
    database = { source = "api", destination = "db", port = 5432 }
  }
}

resource "aws_security_group" "tier" {
  for_each = toset(["web_alb", "web", "api_alb", "api", "db"])
  name     = "${local.name}-${each.key}"
  vpc_id   = module.network.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "operator" {
  security_group_id = aws_security_group.tier["web_alb"].id
  cidr_ipv4         = var.operator_cidr
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "path" {
  for_each                     = local.ingress_paths
  security_group_id            = aws_security_group.tier[each.value.destination].id
  referenced_security_group_id = aws_security_group.tier[each.value.source].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "path" {
  for_each                     = local.ingress_paths
  security_group_id            = aws_security_group.tier[each.value.source].id
  referenced_security_group_id = aws_security_group.tier[each.value.destination].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

# Private tasks pull ECR layers, send logs and fetch migration secrets over HTTPS.
resource "aws_vpc_security_group_egress_rule" "https" {
  for_each          = local.tiers
  security_group_id = aws_security_group.tier[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_lb" "service" {
  for_each           = local.tiers
  name               = "${local.name}-${each.key}"
  internal           = each.key == "api"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tier["${each.key}_alb"].id]
  subnets            = each.key == "api" ? module.network.private_subnets : module.network.public_subnets
  depends_on         = [module.network]
}

resource "aws_lb_target_group" "service" {
  for_each             = local.tiers
  name                 = "${local.name}-${each.key}"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.network.vpc_id
  deregistration_delay = 20
  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "service" {
  for_each          = local.tiers
  load_balancer_arn = aws_lb.service[each.key].arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }
}
