mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-west-2" } }
  mock_data "aws_prefix_list" { defaults = { id = "pl-0123456789abcdef0" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  vpc_name        = yamldecode(file("../../deployments/dev/us-west-2/vpc-smoke/service.example.yaml")).vpc_name
  cidr_block      = yamldecode(file("../../deployments/dev/us-west-2/vpc-smoke/service.example.yaml")).cidr_block
  environment     = "dev"
  project_name    = "vpc-smoke"
  project_version = "example"
}

run "sample_plan" { command = plan }
