locals {
  # Flatten public subnets into a clean lookup map
  public_subnets_map = {
    for subnet in var.vpc_subnets.public : subnet.name => subnet
  }

  # Flatten private subnets into a clean lookup map
  private_subnets_map = {
    for subnet in var.vpc_subnets.private : subnet.name => subnet
  }

  # Combine both subnet types so we can run lookups against them globally
  all_subnets_map = merge(local.public_subnets_map, local.private_subnets_map)

  # Build a distinct list of route table to subnet mapping definitions
  route_table_associations = flatten([
    for rt_key, rt_val in var.route_tables : [
      for subnet_name in rt_val.subnet_associations : {
        key             = "${rt_key}-${subnet_name}"
        route_table_key = rt_key
        subnet_name     = subnet_name
      }
    ]
  ])

  # NAT gateway sentinel resolution: maps "nat_az1"/"nat_az2"/"nat_single" route
  # references to the actual NAT gateway resource keys created below.
  nat_gateway_keys = var.nat_gateway.strategy == "single" ? ["nat_single"] : [
    for idx in range(var.nat_gateway.count) : "nat_az${idx + 1}"
  ]

  # Routes are created as separate resources (rather than inline `route` blocks)
  # so igw/nat sentinels can be resolved cleanly per route.
  flattened_routes = flatten([
    for rt_key, rt in var.route_tables : [
      for ridx, r in rt.routes : {
        key                    = "${rt_key}-${ridx}"
        route_table_key        = rt_key
        destination_cidr_block = r.destination_cidr_block
        gateway_id             = try(r.gateway_id, null)
        nat_gateway_id         = try(r.nat_gateway_id, null)
      }
    ]
  ])

  flattened_associations = flatten([
    for rt_key, rt in var.route_tables : [
      for subnet_name in rt.subnet_associations : {
        key             = "${rt_key}-${subnet_name}"
        route_table_key = rt_key
        subnet_name     = subnet_name
        is_public       = contains(keys(local.public_subnets_map), subnet_name)
      }
    ]
  ])

  # Flattened Security Group Ingress Rules Map
  sg_ingress_rules = {
    for item in flatten([
      for sg_key, sg in var.security_groups : [
        for idx, rule in sg.ingress_rules : [
          for cidr in toset(rule.cidr_blocks) : {
            key         = "${sg_key}-ingress-${idx}-${cidr}"
            sg_key      = sg_key
            description = rule.description
            from_port   = rule.from_port
            to_port     = rule.to_port
            protocol    = rule.protocol
            cidr_ipv4   = cidr
          }
        ]
      ]
    ]) : item.key => item
  }

  # Flattened Security Group Egress Rules Map
  sg_egress_rules = {
    for item in flatten([
      for sg_key, sg in var.security_groups : [
        for idx, rule in sg.egress_rules : [
          for cidr in toset(rule.cidr_blocks) : {
            key         = "${sg_key}-egress-${idx}-${cidr}"
            sg_key      = sg_key
            description = rule.description
            from_port   = rule.from_port
            to_port     = rule.to_port
            protocol    = rule.protocol
            cidr_ipv4   = cidr
          }
        ]
      ]
    ]) : item.key => item
  }
}
