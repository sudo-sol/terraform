locals {
  account_tags = var.account_name == null ? {} : { AccountName = var.account_name }
  default_tags = merge(var.tags, local.account_tags, {
    ManagedBy = "Terraform"
    Project   = "00-bootstrap"
  })

  # Render this with terraform console before attaching it using an existing administrator.
  bootstrap_identity_policy = templatefile("${path.module}/../../policies/tf-bootstrap.json.tftpl", {
    account_id  = var.account_id
    dev_bucket  = var.state_bucket_names.dev
    prod_bucket = var.state_bucket_names.prod
  })
}
