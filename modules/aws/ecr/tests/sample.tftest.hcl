mock_provider "aws" {}

run "sample_plan" {
  command = plan

  assert {
    condition = toset(keys(aws_ecr_repository.ecr_repo)) == toset(var.ecr_repositories[*].name) && alltrue([
      for repo in var.ecr_repositories : aws_ecr_repository.ecr_repo[repo.name].image_scanning_configuration[0].scan_on_push == repo.scan_on_push
    ])
    error_message = "The repositories and scan settings must match the deployment inputs."
  }
}
