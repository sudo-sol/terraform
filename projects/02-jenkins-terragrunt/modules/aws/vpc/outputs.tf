output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet names to their generated AWS subnet IDs"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet names to their generated AWS subnet IDs"
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway, if deployed"
  value       = length(aws_internet_gateway.igw) > 0 ? aws_internet_gateway.igw[0].id : null
}

output "nat_gateway_ids" {
  description = "List of generated NAT Gateway IDs"
  value       = [for k, v in aws_nat_gateway.nat : v.id]
}

output "nat_gateway_public_ips" {
  description = "List of Elastic IPs assigned to the NAT Gateways"
  value       = [for k, v in aws_eip.nat : v.public_ip]
}

output "route_table_ids" {
  description = "Map of route table internal identifiers to AWS route table IDs"
  value       = { for k, v in aws_route_table.route_table : k => v.id }
}

output "security_group_ids" {
  description = "Map of security group identifiers to AWS security group IDs"
  value       = { for k, v in aws_security_group.security : k => v.id }
}
