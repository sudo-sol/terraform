# Credentials come from the AWS CLI profile selected through AWS_PROFILE.
# The default provider handles dev and the account-wide OIDC provider.
provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "prod"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.default_tags
  }
}
