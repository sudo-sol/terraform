mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-west-2" } }
  mock_data "aws_prefix_list" { defaults = { id = "pl-0123456789abcdef0" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  vpc             = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).vpc
  ecs             = yamldecode(file("../../deployments/dev/us-west-2/ecs-demo/service.example.yaml")).ecs
  environment     = "dev"
  project_name    = "ecs-demo"
  project_version = "example"
  managed_by      = "terragrunt"
}

run "sample_plan" { command = plan }
