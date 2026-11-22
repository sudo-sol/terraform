include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//stacks/ecs-demo"
}

locals {
  example  = yamldecode(file("${get_terragrunt_dir()}/service.example.yaml"))
  override = yamldecode(try(file("${get_terragrunt_dir()}/service.local.yaml"), "{}"))
}

inputs = merge(
  local.example,
  local.override,
  {
    ecs = {
      for name, cluster in try(local.override.ecs, local.example.ecs) : name => merge(cluster, {
        ecr_repo_url = replace(cluster.ecr_repo_url, "000000000000", coalesce(get_env("TG_AWS_ACCOUNT_ID", ""), "000000000000"))
      })
    }
    environment     = "dev"
    project_name    = "ecs-demo"
    project_version = "example"
    managed_by      = "terragrunt"
  }
)
