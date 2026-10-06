# ALB Module - Application Load Balancer Resources

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.name_prefix} ALB"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups  = length(ingress.value.security_groups) > 0 ? ingress.value.security_groups : null
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-alb"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true # prevent HTTP desync attacks
  idle_timeout                     = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.access_logs_enabled
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-alb"
    }
  )
}

# Target Group for ECS Fargate (target_type = ip)
resource "aws_lb_target_group" "ecs" {
  name                 = "${var.name_prefix}-ecs-tg"
  port                 = var.target_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"  # Required for ECS Fargate
  deregistration_delay = 30
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-tg"
      Type = "ECS-Fargate"
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

# HTTP listener: redirects to HTTPS when a certificate is set and http_redirect_to_https = true,
# otherwise forwards port 80 straight to the target group (plain-HTTP / ws:// clients).
locals {
  http_redirect = var.certificate_arn != "" && var.http_redirect_to_https
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = local.http_redirect ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.http_redirect ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = local.http_redirect ? null : aws_lb_target_group.ecs.arn
  }
}

# HTTPS listener – created only when certificate_arn is provided.
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}
