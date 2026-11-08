locals {
  default_tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Project   = "00-bootstrap"
  })
}
