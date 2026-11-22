resource "aws_vpc" "smoke" {
  cidr_block = var.cidr_block
  tags = {
    Environment = var.environment
    Version     = var.project_version
    Project     = var.project_name
    Name        = var.vpc_name
  }
}
