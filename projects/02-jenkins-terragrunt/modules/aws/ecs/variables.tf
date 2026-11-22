variable "cluster_name" {
  description = "The name of the ECS Cluster that will host the app"
  type        = string
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repo containing the application container image"
  type        = string
}

variable "log_group_name" {
  description = "The name of the CloudWatch log group where flow logs will be sent"
  type        = string
}

variable "log_retention" {
  description = "Number of days to retain the logs"
  type        = number
}

variable "vpc_id" {
  description = "The id of the VPC where the ECS cluster will be deployed to"
  type        = string
}

variable "public_subnets" {
  description = "The ids of the public subnets in the VPC"
  type        = list(string)
}

variable "private_subnets" {
  description = "The ids of the public subnets in the VPC"
  type        = list(string)
}

variable "alb_security_group" {
  description = "The Security group used by the Application Loadbalancer"
  type        = string
}

variable "app_security_group" {
  description = "The Security group used by the ECS Service running the application"
  type        = string
}

variable "capacity_providers" {
  type = list(object({
    name   = string
    weight = number
    base   = number
  }))
}

variable "service" {
  type = object({
    name                              = string
    container_name                    = string
    container_port                    = number
    cpu                               = number
    memory                            = number
    desired_count                     = number
    health_check_grace_period_seconds = number
  })
}

variable "alb" {
  type = object({
    name                          = string
    internal                      = bool
    listener_port                 = number
    health_check_path             = string
    health_check_interval_seconds = number
    health_check_timeout_seconds  = number
    healthy_threshold             = number
    unhealthy_threshold           = number
    deregistration_delay_seconds  = number
  })
}

variable "autoscaling" {
  type = object({
    min_capacity               = number
    max_capacity               = number
    scale_in_cooldown_seconds  = number
    scale_out_cooldown_seconds = number
    metrics = list(object({
      type         = string
      target_value = number
    }))
  })
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}
