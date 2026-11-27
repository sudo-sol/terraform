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

provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = { Project = local.name, Environment = "dev", ManagedBy = "Terraform" }
  }
}

variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply a 12-digit AWS account ID."
  }
}

variable "operator_cidr" {
  description = "Operator IPv4 CIDR permitted to reach the demo."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.operator_cidr)) && try(tonumber(split("/", var.operator_cidr)[1]) > 0, false)
    error_message = "Supply a restricted IPv4 CIDR such as your public address with /32."
  }
}

locals {
  name = "eks-workers-dev"
}

module "network" {
  source             = "../../../../../modules/aws/two-az-dev-network"
  name               = local.name
  cidr               = "10.30.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b"]
}
