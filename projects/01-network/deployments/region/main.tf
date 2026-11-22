terraform {
  required_version = "~> 1.17.0"

  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72.0"
    }
  }
}

locals {
  regions = {
    dev  = "us-west-2"
    prod = "us-east-1"
  }
}

provider "aws" {
  region              = local.regions[var.target]
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Environment = var.target
      ManagedBy   = "Terraform"
      Project     = "01-network"
    }
  }
}

module "network" {
  source = "../../stack"

  name                 = var.network.name
  availability_zones   = var.network.availability_zones
  vpc_cidrs            = var.network.vpc_cidrs
  private_zone_name    = var.network.private_zone_name
  private_records      = var.network.private_records
  resolver             = var.network.resolver
  allow_spoke_to_spoke = var.target == "dev"
  firewall             = var.network.firewall
}
