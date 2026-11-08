# Example values only. Copy to terraform.tfvars and use your own identifiers.
account_id = "123456789012"

state_bucket_names = {
  dev  = "terraform-state-123456789012-dev-us-west-2"
  prod = "terraform-state-123456789012-prod-us-east-1"
}

tags = {
  Repository = "example-owner/example-repo"
}

# Replace names AND IDs with the prefix from your repository's OIDC settings.
# For a legacy subject, use repo:YOUR_OWNER/YOUR_REPO:ref:refs/heads/... instead.
github_oidc_subjects = {
  dev = [
    "repo:example-owner@123456/example-repo@789012:ref:refs/heads/*"
  ]
  prod = [
    "repo:example-owner@123456/example-repo@789012:ref:refs/heads/main"
  ]
}
