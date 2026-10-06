# ECS Service Module - Per Application Service
# Note: TaskDefinition should be created separately and passed via task_definition_arn

# ECS Tasks Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${var.service_name}-ecs-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.service_name} ECS tasks"

  dynamic "ingress" {
    for_each = var.alb_security_group_id != "" ? [1] : []
    content {
      description     = "All Mieruca Heatmap ALB access"
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name    = "${var.service_name}-ecs"
    Service = var.service_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Application Logs (Per Service)
resource "aws_cloudwatch_log_group" "ecs_service" {
  name              = "/aws/ecs/service/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-app-logs"
    Service = var.service_name
    Cluster = var.cluster_name
    Type = "ApplicationLogs"
  })
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.service_name}-service"
  cluster         = var.cluster_id
  task_definition = var.task_definition_arn
  desired_count   = var.desired_count

  # Launch Type (Fargate)
  launch_type = "FARGATE"

  # Network Configuration (Fargate)
  network_configuration {
    subnets          = var.assign_public_ip ? var.public_subnet_ids : var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.assign_public_ip
  }

  # Load Balancer Configuration
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # Service Discovery
  dynamic "service_registries" {
    for_each = var.service_discovery_arn != "" ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Enable Execute Command
  enable_execute_command = var.enable_execute_command

  # Health check grace period - only applicable when a load balancer is attached
  health_check_grace_period_seconds = var.target_group_arn != "" ? var.health_check_grace_period_seconds : null

  tags = var.common_tags
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.enable_auto_scaling ? 1 : 0
  max_capacity       = var.auto_scaling_max_capacity
  min_capacity       = var.auto_scaling_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Auto Scaling Policy - Memory
# Ensures scale-out when memory is high even if CPU is low (e.g. memory-intensive Java workloads).
# Both CPU and Memory policies coexist – ECS scales out on whichever triggers first.
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.service_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# CloudWatch Alarm - Memory High Warning (Alert only, no autoscaling)
resource "aws_cloudwatch_metric_alarm" "memory_high_warning" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "${var.service_name}-memory-high-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = 85   # 85% memory usage
  alarm_description   = "Memory usage is high (>85%) - possible memory leak or need to investigate"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.main.name
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}

# CloudWatch Alarm - Memory Critical (Alert only, no autoscaling)
resource "aws_cloudwatch_metric_alarm" "memory_critical" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "${var.service_name}-memory-critical"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60   # 1 minute
  statistic           = "Average"
  threshold           = 95   # 95% memory usage
  alarm_description   = "CRITICAL: Memory usage is very high (>95%) - OOM imminent"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.main.name
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "zero_running_tasks" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "${var.service_name}-zero-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "CRITICAL: no running tasks for ${var.service_name} - service is completely down"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.main.name
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}

# CloudWatch Alarm - CPU High (Alert only, no autoscaling)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "${var.service_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = 80   # 80% CPU usage across the service
  alarm_description   = "CPU usage is high (>80% average) - approaching capacity limits"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.main.name
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}

# CloudWatch Alarm for task count monitoring
resource "aws_cloudwatch_metric_alarm" "service_task_count_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "${var.service_name}-task-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = var.task_count_alarm_threshold
  alarm_description   = "Alert when running task count exceeds threshold (possible over-scaling or high load)"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.main.name
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}