module "bootstrap" {
  source = "../../stack"

  providers = {
    aws      = aws
    aws.prod = aws.prod
  }

  state_bucket_names   = var.state_bucket_names
  github_oidc_subjects = var.github_oidc_subjects
}
