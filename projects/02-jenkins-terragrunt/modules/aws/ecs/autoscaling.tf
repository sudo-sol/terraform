## Autoscaling policies

resource "aws_appautoscaling_target" "scaling" {
  max_capacity       = var.autoscaling.max_capacity
  min_capacity       = var.autoscaling.min_capacity
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "metrics" {
  for_each = { for metric in var.autoscaling.metrics : metric.type => metric }

  name               = "${var.service.name}-${each.value.type}-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.scaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_value
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown_seconds
    scale_out_cooldown = var.autoscaling.scale_out_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = lookup(local.metric_mapping, each.value.type, "ECSServiceAverageCPUUtilization")
    }
  }
}
