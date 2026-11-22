output "ecr_repository_uris" {
  description = "List of ECR repository URIs"
  value       = [for repo in aws_ecr_repository.ecr_repo : repo.repository_url]

}
