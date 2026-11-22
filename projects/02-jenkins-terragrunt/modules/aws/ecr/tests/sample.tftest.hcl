mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-west-2" } }
  mock_data "aws_prefix_list" { defaults = { id = "pl-0123456789abcdef0" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  ecr_repositories = yamldecode(file("../../../deployments/dev/us-west-2/ecr/service.example.yaml")).ecr_repositories
  environment      = "dev"
  project_name     = "ecr"
  project_version  = "example"
  managed_by       = "terragrunt"
}

run "sample_plan" { command = plan }
