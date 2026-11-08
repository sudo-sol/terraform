output "state_backends" {
  description = "Backend settings for future projects. Each deployment adds its own state key."
  value = {
    dev = {
      bucket       = aws_s3_bucket.dev.id
      region       = "us-west-2"
      encrypt      = true
      use_lockfile = true
    }
    prod = {
      bucket       = aws_s3_bucket.prod.id
      region       = "us-east-1"
      encrypt      = true
      use_lockfile = true
    }
  }
}

output "github_oidc_provider_arn" {
  description = "OIDC provider shared by both GitHub Actions roles."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arns" {
  description = "Role ARNs to select by environment in GitHub Actions."
  value = {
    dev  = aws_iam_role.github_actions_dev.arn
    prod = aws_iam_role.github_actions_prod.arn
  }
}
