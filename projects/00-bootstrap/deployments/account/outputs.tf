output "state_backends" {
  description = "Backend settings for future projects. Each deployment adds its own state key."
  value       = module.bootstrap.state_backends
}

output "github_oidc_provider_arn" {
  description = "OIDC provider shared by both GitHub Actions roles."
  value       = module.bootstrap.github_oidc_provider_arn
}

output "github_actions_role_arns" {
  description = "Role ARNs to select by environment in GitHub Actions."
  value       = module.bootstrap.github_actions_role_arns
}
