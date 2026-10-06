# ALB Target Group Module - Creates standalone target groups for existing ALB

resource "aws_lb_target_group" "this" {
  name                 = var.name
  port                 = var.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"  # Required for ECS Fargate
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
  }

  tags = merge(
    var.common_tags,
    {
      Name = var.name
      Type = "ECS-Fargate"
    }
  )

  lifecycle {
    create_before_destroy = false
  }
}

