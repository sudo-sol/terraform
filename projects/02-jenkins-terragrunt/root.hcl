terraform_binary = "terraform"

locals {
  region     = "us-west-2"
  account_id = coalesce(get_env("TG_AWS_ACCOUNT_ID", ""), "000000000000")
  bucket     = coalesce(get_env("TG_STATE_BUCKET", ""), "replace-with-your-state-bucket")
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      backend "s3" {
        bucket              = ${jsonencode(local.bucket)}
        key                 = ${jsonencode("02-jenkins-terragrunt/${path_relative_to_include()}/terraform.tfstate")}
        region              = ${jsonencode(local.region)}
        allowed_account_ids = [${jsonencode(local.account_id)}]
        encrypt             = true
        use_lockfile        = true
      }
    }
  HCL
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      required_version = "~> 1.17.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.72.0"
        }
      }
    }

    provider "aws" {
      region              = ${jsonencode(local.region)}
      allowed_account_ids = [${jsonencode(local.account_id)}]
    }
  HCL
}
