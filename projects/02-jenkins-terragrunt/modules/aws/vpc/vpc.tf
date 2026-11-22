# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.public_subnets_map

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value["cidr"]
  availability_zone = each.value["availability_zone"]

  tags = merge(var.tags, {
    Name = each.value["name"]
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets_map

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value["cidr"]
  availability_zone = each.value["availability_zone"]

  tags = merge(var.tags, {
    Name = each.value["name"]
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  count = var.internet_gateway.enabled ? 1 : 0

  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = var.internet_gateway.name
  })
}

# ---------------------------------------------------------------------------
# NAT Gateway(s)
#
# strategy = "per_az": one NAT + EIP per AZ represented in the public subnets.
#            Provides HA but egress traffic can originate from more than one IP.
# strategy = "single":  one NAT + EIP shared by all private subnets/AZs.
#            Required when downstream partners whitelist by a single fixed IP.
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_keys)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = lookup(
      { for idx, name in var.nat_gateway.elastic_ips : local.nat_gateway_keys[idx] => name
        if idx < length(local.nat_gateway_keys)
      },
      each.key,
      "${var.vpc_name}-${each.key}-eip"
    )
  })
}

resource "aws_nat_gateway" "nat" {
  for_each = toset(local.nat_gateway_keys)

  allocation_id = aws_eip.nat[each.key].id

  # per_az: nat_az1 -> first public subnet, nat_az2 -> second public subnet, etc.
  # single: pin to the first public subnet.
  subnet_id = var.nat_gateway.strategy == "single" ? values(aws_subnet.public)[0].id : values(aws_subnet.public)[
    index(local.nat_gateway_keys, each.key)
  ].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-${each.key}-nat"
  })

  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------

resource "aws_route_table" "route_table" {
  for_each = var.route_tables

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    each.value.tags, {
      Name = each.value.name
  })
}

resource "aws_route" "routes" {
  for_each = { for route in local.flattened_routes : route.key => route }

  route_table_id         = aws_route_table.route_table[each.value["route_table_key"]].id
  destination_cidr_block = each.value["destination_cidr_block"]
  gateway_id             = each.value["gateway_id"] == "igw" ? one(aws_internet_gateway.igw[*].id) : null

  # Safely check if the target NAT key exists. If it doesn't, fall back to the single/first NAT gateway.
  nat_gateway_id = each.value["nat_gateway_id"] != null ? (
    contains(keys(aws_nat_gateway.nat), each.value["nat_gateway_id"]) ?
    aws_nat_gateway.nat[each.value["nat_gateway_id"]].id :
    values(aws_nat_gateway.nat)[0].id
  ) : null
}

resource "aws_route_table_association" "rt_association" {
  for_each = { for as in local.flattened_associations : as.key => as }

  route_table_id = aws_route_table.route_table[each.value["route_table_key"]].id
  subnet_id      = each.value["is_public"] ? aws_subnet.public[each.value["subnet_name"]].id : aws_subnet.private[each.value["subnet_name"]].id
}
