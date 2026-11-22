output "workload_subnet_ids" {
  description = "Private workload subnet IDs keyed by VPC name and Availability Zone."
  value       = { for key, subnet in aws_subnet.workload : key => subnet.id }
}

output "vpc_ids" {
  description = "VPC IDs keyed by their role in the topology."
  value       = { for name, vpc in aws_vpc.this : name => vpc.id }
}

output "transit_route_table_ids" {
  description = "Transit Gateway route table IDs keyed by the attachment that uses each table."
  value       = { for name, table in aws_ec2_transit_gateway_route_table.this : name => table.id }
}

output "private_zone_id" {
  description = "ID of the private hosted zone."
  value       = aws_route53_zone.private.zone_id
}

output "resolver_inbound_ips" {
  description = "Resolver inbound endpoint IPs for conditional forwarding from spoke B."
  value = var.resolver == null ? [] : sort([
    for address in aws_route53_resolver_endpoint.this["INBOUND"].ip_address : address.ip
  ])
}

output "firewall_log_groups" {
  description = "CloudWatch log groups keyed by Network Firewall log type."
  value       = { for type, group in aws_cloudwatch_log_group.firewall : type => group.name }
}
