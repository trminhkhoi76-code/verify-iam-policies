resource "aws_elasticache_subnet_group" "valkey" {
  name       = "${var.cluster_name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-subnet-group"
    }
  )
}

resource "aws_security_group" "valkey" {
  name        = "${var.cluster_name}-sg"
  vpc_id      = var.vpc_id
  description = "Security group for Valkey cluster"

   dynamic "ingress" {
     for_each = var.ingress_rules
     content {
       description      = ingress.value.description
       from_port        = coalesce(ingress.value.from_port, 6379)
       to_port          = coalesce(ingress.value.to_port, 6379)
       protocol         = ingress.value.protocol
       cidr_blocks      = try(length(ingress.value.cidr_blocks) > 0, false) ? ingress.value.cidr_blocks : null
       security_groups  = ingress.value.security_group_id != null ? [ingress.value.security_group_id] : null
     }
   }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_parameter_group" "valkey" {
  name        = "${var.cluster_name}-params"
  family      = "valkey${split(".", var.engine_version)[0]}"
  description = "Custom parameter group for ${var.cluster_name}"

  dynamic "parameter" {
    for_each = var.parameter_group_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-params"
    }
  )
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = var.cluster_name
  description          = "${var.cluster_name} Valkey cluster"
  
  # Engine configuration
  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = var.node_type
  port          = var.port
  
  # Cluster configuration
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled          = var.multi_az_enabled
  
  # Parameter group
  parameter_group_name = var.create_parameter_group ? aws_elasticache_parameter_group.valkey.name : null

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.valkey.name
  security_group_ids = [aws_security_group.valkey.id]
  
  # Backup configuration
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window         = var.snapshot_window
  maintenance_window      = var.maintenance_window
  
  # Security configuration
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  
  apply_immediately = true

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.valkey_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )

  depends_on = [
    aws_elasticache_subnet_group.valkey,
    aws_security_group.valkey,
    aws_cloudwatch_log_group.valkey_slow
  ]
}

resource "aws_cloudwatch_log_group" "valkey_slow" {
  name              = "/aws/elasticache/valkey/${var.cluster_name}/slow-log"
  retention_in_days = var.log_retention_in_days

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-slow-log"
    }
  )
}

# CloudWatch Alarms - Simple replication group level monitoring
resource "aws_cloudwatch_metric_alarm" "valkey_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors valkey cpu utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = tolist(aws_elasticache_replication_group.valkey.member_clusters)[0]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "valkey_memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-low-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "This metric monitors valkey freeable memory"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = tolist(aws_elasticache_replication_group.valkey.member_clusters)[0]
  }

  tags = var.tags
}