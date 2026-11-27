# Preserve existing project 02 endpoint and security-rule addresses.
moved {
  from = aws_vpc_security_group_egress_rule.app_to_vpce
  to   = aws_vpc_security_group_egress_rule.app_to_vpce[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.vpce_from_app
  to   = aws_vpc_security_group_ingress_rule.vpce_from_app[0]
}

moved {
  from = aws_vpc_endpoint.ecr_api
  to   = aws_vpc_endpoint.ecr_api[0]
}

moved {
  from = aws_vpc_endpoint.ecr_dkr
  to   = aws_vpc_endpoint.ecr_dkr[0]
}

moved {
  from = aws_vpc_endpoint.logs
  to   = aws_vpc_endpoint.logs[0]
}

moved {
  from = aws_vpc_endpoint.s3
  to   = aws_vpc_endpoint.s3[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.app_to_s3_gateway
  to   = aws_vpc_security_group_egress_rule.app_to_s3_gateway[0]
}
