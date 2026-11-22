locals {
  spokes             = { spoke_a = "spoke_b", spoke_b = "spoke_a" }
  workload_vpcs      = toset(["spoke_a", "spoke_b", "shared"])
  inspection_enabled = var.firewall != null
  az_indexes         = { for index, az in var.availability_zones : az => index }
  nat_azs            = local.inspection_enabled ? toset(var.availability_zones) : toset(slice(var.availability_zones, 0, 1))
  dns_vpcs           = toset(["spoke_a", "shared"])

  transit_subnets = {
    for pair in setproduct(keys(var.vpc_cidrs), var.availability_zones) : "${pair[0]}/${pair[1]}" => {
      vpc = pair[0]
      az  = pair[1]
    }
  }
  workload_subnets = {
    for key, subnet in local.transit_subnets : key => subnet if subnet.vpc != "egress"
  }
}

resource "aws_vpc" "this" {
  for_each = var.vpc_cidrs

  cidr_block           = each.value
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-${each.key}" }
}

resource "aws_subnet" "workload" {
  for_each = local.workload_subnets

  vpc_id            = aws_vpc.this[each.value.vpc].id
  availability_zone = each.value.az
  cidr_block        = cidrsubnet(var.vpc_cidrs[each.value.vpc], 4, local.az_indexes[each.value.az])

  tags = { Name = "${var.name}-${each.value.vpc}-workload-${each.value.az}" }
}

resource "aws_subnet" "transit" {
  for_each = local.transit_subnets

  vpc_id            = aws_vpc.this[each.value.vpc].id
  availability_zone = each.value.az
  cidr_block        = cidrsubnet(var.vpc_cidrs[each.value.vpc], 4, 2 + local.az_indexes[each.value.az])

  tags = { Name = "${var.name}-${each.value.vpc}-transit-${each.value.az}" }
}

resource "aws_route_table" "workload" {
  for_each = local.workload_vpcs

  vpc_id = aws_vpc.this[each.key].id
  tags   = { Name = "${var.name}-${each.key}-workload" }
}

resource "aws_route_table_association" "workload" {
  for_each = local.workload_subnets

  subnet_id      = aws_subnet.workload[each.key].id
  route_table_id = aws_route_table.workload[each.value.vpc].id
}

resource "aws_route" "spoke_default" {
  for_each = local.spokes

  route_table_id         = aws_route_table.workload[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route" "shared_to_spoke" {
  for_each = local.spokes

  route_table_id         = aws_route_table.workload["shared"].id
  destination_cidr_block = var.vpc_cidrs[each.key]
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
