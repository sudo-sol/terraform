resource "aws_ec2_transit_gateway" "this" {
  description                     = "Regional transit for ${var.name}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"

  tags = { Name = var.name }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = aws_vpc.this

  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = each.value.id
  subnet_ids                                      = [for az in var.availability_zones : aws_subnet.transit["${each.key}/${az}"].id]
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  appliance_mode_support                          = each.key == "egress" && local.inspection_enabled ? "enable" : "disable"

  tags = { Name = "${var.name}-${each.key}" }
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = aws_vpc.this

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name}-${each.key}" }
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.this

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.key].id
}

resource "aws_ec2_transit_gateway_route" "spoke_default" {
  for_each = local.spokes

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.key].id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["egress"].id
}

resource "aws_ec2_transit_gateway_route" "spoke_to_peer" {
  for_each = local.spokes

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.key].id
  destination_cidr_block         = var.vpc_cidrs[each.value]
  transit_gateway_attachment_id  = var.allow_spoke_to_spoke ? aws_ec2_transit_gateway_vpc_attachment.this[each.value].id : null
  blackhole                      = !var.allow_spoke_to_spoke
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_into_spoke" {
  for_each = local.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["shared"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.key].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_into_shared_and_egress" {
  for_each = {
    for pair in setproduct(keys(local.spokes), ["shared", "egress"]) : "${pair[0]}/${pair[1]}" => {
      spoke = pair[0]
      table = pair[1]
    }
  }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.spoke].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.table].id
}
