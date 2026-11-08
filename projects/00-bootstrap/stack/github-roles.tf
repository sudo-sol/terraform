resource "aws_iam_role" "github_actions_dev" {
  name        = "role-terraform-github-actions-dev"
  description = "Terraform access for the dev environment"
  tags        = { Environment = "dev" }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.github_oidc_subjects.dev
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_dev_backend" {
  name = "policy-terraform-github-actions-dev"
  role = aws_iam_role.github_actions_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateBucketMetadata"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.dev.arn
      },
      {
        Sid      = "StateAndLockObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.dev.arn}/*"
      },
      {
        Sid      = "DeleteLockFiles"
        Effect   = "Allow"
        Action   = "s3:DeleteObject"
        Resource = "${aws_s3_bucket.dev.arn}/*.tflock"
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_prod" {
  name        = "role-terraform-github-actions-prod"
  description = "Terraform access for the prod environment"
  tags        = { Environment = "prod" }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = var.github_oidc_subjects.prod
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_prod_backend" {
  name = "policy-terraform-github-actions-prod"
  role = aws_iam_role.github_actions_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateBucketMetadata"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.prod.arn
      },
      {
        Sid      = "StateAndLockObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.prod.arn}/*"
      },
      {
        Sid      = "DeleteLockFiles"
        Effect   = "Allow"
        Action   = "s3:DeleteObject"
        Resource = "${aws_s3_bucket.prod.arn}/*.tflock"
      }
    ]
  })
}
