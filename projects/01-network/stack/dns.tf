locals {
  resolver_endpoints = var.resolver == null ? toset([]) : toset(["INBOUND", "OUTBOUND"])
  resolver_targets   = var.resolver == null ? toset([]) : var.resolver.target_ips
}

resource "aws_route53_zone" "private" {
  name = var.private_zone_name

  dynamic "vpc" {
    for_each = local.dns_vpcs
    content {
      vpc_id = aws_vpc.this[vpc.key].id
    }
  }
}

resource "aws_route53_record" "private" {
  for_each = var.private_records

  zone_id = aws_route53_zone.private.zone_id
  name    = each.key
  type    = "A"
  ttl     = 60
  records = each.value
}

resource "aws_security_group" "resolver" {
  for_each = local.resolver_endpoints

  name        = "${var.name}-dns-${lower(each.key)}"
  description = "Route 53 Resolver ${lower(each.key)}"
  vpc_id      = aws_vpc.this["shared"].id
}

resource "aws_vpc_security_group_ingress_rule" "resolver_inbound" {
  for_each = var.resolver == null ? toset([]) : toset(["tcp", "udp"])

  security_group_id = aws_security_group.resolver["INBOUND"].id
  cidr_ipv4         = var.vpc_cidrs.spoke_b
  ip_protocol       = each.key
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "resolver_outbound" {
  for_each = {
    for pair in setproduct(local.resolver_targets, ["tcp", "udp"]) : "${pair[0]}/${pair[1]}" => {
      ip       = pair[0]
      protocol = pair[1]
    }
  }

  security_group_id = aws_security_group.resolver["OUTBOUND"].id
  cidr_ipv4         = "${each.value.ip}/32"
  ip_protocol       = each.value.protocol
  from_port         = 53
  to_port           = 53
}

resource "aws_route53_resolver_endpoint" "this" {
  for_each = local.resolver_endpoints

  name               = "${var.name}-${lower(each.key)}"
  direction          = each.key
  security_group_ids = [aws_security_group.resolver[each.key].id]

  dynamic "ip_address" {
    for_each = local.az_indexes
    content {
      subnet_id = aws_subnet.workload["shared/${ip_address.key}"].id
    }
  }
}

resource "aws_route53_resolver_rule" "forward" {
  count = var.resolver == null ? 0 : 1

  name                 = "${var.name}-forward"
  domain_name          = var.resolver.forward_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.this["OUTBOUND"].id

  dynamic "target_ip" {
    for_each = local.resolver_targets
    content {
      ip   = target_ip.value
      port = 53
    }
  }
}

resource "aws_route53_resolver_rule_association" "forward" {
  for_each = var.resolver == null ? toset([]) : local.dns_vpcs

  resolver_rule_id = aws_route53_resolver_rule.forward[0].id
  vpc_id           = aws_vpc.this[each.key].id
}
