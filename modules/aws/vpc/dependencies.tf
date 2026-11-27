data "aws_region" "current" {}

data "aws_prefix_list" "s3" {
  count = var.enable_ecs_endpoints ? 1 : 0
  name  = "com.amazonaws.${data.aws_region.current.region}.s3"
}
