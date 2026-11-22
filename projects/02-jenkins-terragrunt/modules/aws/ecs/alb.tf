## Application Loadbalancer definitions

resource "aws_lb" "app_lb" {
  name               = "${var.alb.name}-alb"
  internal           = var.alb.internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnets

  tags = merge(var.tags, {
    Name = "${var.alb.name}-alb"
  })
}

resource "aws_lb_target_group" "app_alb" {
  name        = "${var.alb.name}-tg"
  port        = var.service.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate network modes

  deregistration_delay = var.alb.deregistration_delay_seconds

  health_check {
    enabled             = true
    path                = var.alb.health_check_path
    interval            = var.alb.health_check_interval_seconds
    timeout             = var.alb.health_check_timeout_seconds
    healthy_threshold   = var.alb.healthy_threshold
    unhealthy_threshold = var.alb.unhealthy_threshold
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.alb.name}-targetgroup"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = var.alb.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_alb.arn
  }

  tags = merge(var.tags, {
    Name = "${var.alb.name}-listener-HTTP"
  })
}
