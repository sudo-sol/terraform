include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//stacks/vpc-smoke"
}

inputs = merge(
  yamldecode(file("${get_terragrunt_dir()}/service.example.yaml")),
  yamldecode(try(file("${get_terragrunt_dir()}/service.local.yaml"), "{}")),
  {
    environment     = "dev"
    project_name    = "vpc-smoke"
    project_version = "example"
  }
)
