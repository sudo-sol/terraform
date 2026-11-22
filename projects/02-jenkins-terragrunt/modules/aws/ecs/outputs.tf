output "alb_dns_name" {
  description = "The DNS name generated for the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}

output "ecs_cluster_id" {
  description = "The AWS resource identification token string tracking the cluster"
  value       = aws_ecs_cluster.cluster.id
}

output "ecs_service_name" {
  description = "The deployment name identifier matching your Fargate tasks configuration map"
  value       = aws_ecs_service.service.name
}

output "task_execution_role_arn" {
  description = "The ARN of the task execution role that the Amazon ECS container and the Docker daemon can assume"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "The ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services"
  value       = aws_iam_role.task.arn
}
