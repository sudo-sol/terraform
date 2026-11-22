resource "aws_ecr_repository" "ecr_repo" {
  for_each = { for repo in var.ecr_repositories : repo.name => repo }

  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  tags = merge(
    local.tags,
    {
      Name = each.key
    }
  )
}

resource "aws_ecr_lifecycle_policy" "ecr_repo_lifecycle_policy" {
  for_each = { for repo in var.ecr_repositories : repo.name => repo }

  repository = aws_ecr_repository.ecr_repo[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${each.value.images_to_keep} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = each.value.images_to_keep
      }
      action = { type = "expire" }
    }]
  })
}
