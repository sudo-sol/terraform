# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "security" {
  for_each = var.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = each.value.name
  })

}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = local.sg_ingress_rules

  security_group_id = aws_security_group.security[each.value["sg_key"]].id
  description       = each.value["description"]
  from_port         = each.value["from_port"]
  to_port           = each.value["to_port"]
  ip_protocol       = each.value["protocol"]
  cidr_ipv4         = each.value["cidr_ipv4"]
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  for_each = local.sg_egress_rules

  security_group_id = aws_security_group.security[each.value["sg_key"]].id
  description       = each.value["description"]
  from_port         = each.value["from_port"]
  to_port           = each.value["to_port"]
  ip_protocol       = each.value["protocol"]
  cidr_ipv4         = each.value["cidr_ipv4"]
}


## Special case Security group rules. This has to be eventually added from the YAML file
resource "aws_vpc_security_group_egress_rule" "app_to_vpce" {
  security_group_id            = aws_security_group.security["app_sg"].id
  description                  = "Allow ECS tasks to reach VPC Endpoints securely"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.security["endpoint_sg"].id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_from_app" {
  security_group_id            = aws_security_group.security["endpoint_sg"].id
  description                  = "Allow incoming HTTPS traffic from ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.security["app_sg"].id
}
