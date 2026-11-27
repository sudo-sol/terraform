include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../../modules/aws/ecr"
}

inputs = merge(
  yamldecode(file("${get_terragrunt_dir()}/service.example.yaml")),
  yamldecode(try(file("${get_terragrunt_dir()}/service.local.yaml"), "{}")),
  {
    environment     = "dev"
    project_name    = "ecr"
    project_version = "example"
    managed_by      = "terragrunt"
  }
)
