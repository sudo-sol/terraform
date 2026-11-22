locals {
  firewall_endpoints = local.inspection_enabled ? {
    for state in aws_networkfirewall_firewall.egress[0].firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  } : {}

  nat_return_routes = {
    for pair in setproduct(local.nat_azs, keys(local.spokes)) : "${pair[0]}/${pair[1]}" => {
      az    = pair[0]
      spoke = pair[1]
    }
  }
}

resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.this["egress"].id
  tags   = { Name = "${var.name}-egress" }
}

resource "aws_subnet" "nat" {
  for_each = local.nat_azs

  vpc_id            = aws_vpc.this["egress"].id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidrs.egress, 4, 4 + local.az_indexes[each.key])

  tags = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_eip" "nat" {
  for_each = local.nat_azs

  domain = "vpc"
  tags   = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "egress" {
  for_each = local.nat_azs

  subnet_id     = aws_subnet.nat[each.key].id
  allocation_id = aws_eip.nat[each.key].id
  tags          = { Name = "${var.name}-nat-${each.key}" }

  depends_on = [aws_internet_gateway.egress]
}

resource "aws_route_table" "nat" {
  for_each = local.nat_azs

  vpc_id = aws_vpc.this["egress"].id
  tags   = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_route_table_association" "nat" {
  for_each = local.nat_azs

  subnet_id      = aws_subnet.nat[each.key].id
  route_table_id = aws_route_table.nat[each.key].id
}

resource "aws_route" "nat_to_internet" {
  for_each = local.nat_azs

  route_table_id         = aws_route_table.nat[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.egress.id
}

# Translated return traffic goes through the same firewall endpoint in prod.
resource "aws_route" "nat_to_spoke" {
  for_each = local.nat_return_routes

  route_table_id         = aws_route_table.nat[each.value.az].id
  destination_cidr_block = var.vpc_cidrs[each.value.spoke]
  vpc_endpoint_id        = local.inspection_enabled ? local.firewall_endpoints[each.value.az] : null
  transit_gateway_id     = local.inspection_enabled ? null : aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route_table" "egress_transit" {
  for_each = local.az_indexes

  vpc_id = aws_vpc.this["egress"].id
  tags   = { Name = "${var.name}-egress-transit-${each.key}" }
}

resource "aws_route_table_association" "egress_transit" {
  for_each = local.az_indexes

  subnet_id      = aws_subnet.transit["egress/${each.key}"].id
  route_table_id = aws_route_table.egress_transit[each.key].id
}

resource "aws_route" "egress_default" {
  for_each = local.az_indexes

  route_table_id         = aws_route_table.egress_transit[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.inspection_enabled ? null : aws_nat_gateway.egress[var.availability_zones[0]].id
  vpc_endpoint_id        = local.inspection_enabled ? local.firewall_endpoints[each.key] : null
}

resource "aws_subnet" "firewall" {
  for_each = local.inspection_enabled ? local.az_indexes : {}

  vpc_id            = aws_vpc.this["egress"].id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidrs.egress, 4, 6 + each.value)

  tags = { Name = "${var.name}-firewall-${each.key}" }
}

resource "aws_route_table" "firewall" {
  for_each = aws_subnet.firewall

  vpc_id = aws_vpc.this["egress"].id
  tags   = { Name = "${var.name}-firewall-${each.key}" }
}

resource "aws_route_table_association" "firewall" {
  for_each = aws_subnet.firewall

  subnet_id      = each.value.id
  route_table_id = aws_route_table.firewall[each.key].id
}

resource "aws_route" "firewall_to_nat" {
  for_each = aws_subnet.firewall

  route_table_id         = aws_route_table.firewall[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.egress[each.key].id
}

resource "aws_route" "firewall_to_spoke" {
  for_each = local.inspection_enabled ? local.nat_return_routes : {}

  route_table_id         = aws_route_table.firewall[each.value.az].id
  destination_cidr_block = var.vpc_cidrs[each.value.spoke]
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
