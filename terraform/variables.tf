variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "heatmap-japan"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Existing subnet IDs for Valkey"
  type        = list(string)
}

variable "valkey_ingress_rules" {
  description = "List of ingress rules for Valkey with security group IDs and descriptions"
  type = list(object({
    security_group_id        = optional(string, null)
    cidr_blocks              = optional(list(string), null)
    description              = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# Valkey variables
variable "valkey_node_type" {
  description = "The instance class for Valkey nodes"
  type        = string
  default     = "cache.t3.micro"
}

variable "valkey_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

variable "valkey_engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.1"
}

variable "valkey_multi_az_enabled" {
  description = "Specifies whether to enable Multi-AZ Support"
  type        = bool
  default     = true
}

variable "valkey_at_rest_encryption_enabled" {
  description = "Whether to enable encryption at rest"
  type        = bool
  default     = true
}

variable "valkey_transit_encryption_enabled" {
  description = "Whether to enable encryption in transit"
  type        = bool
  default     = true
}

variable "valkey_snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "valkey_snapshot_window" {
  description = "Time window for snapshots"
  type        = string
  default     = "03:00-04:00"
}

variable "valkey_maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "valkey_enable_cloudwatch_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "valkey_alarm_actions" {
    description = "List of SNS topic ARNs for CloudWatch alarms"
    type        = list(string)
    default     = []
}

variable "valkey_memory_alarm_threshold" {
    description = "Threshold (in bytes) for the CloudWatch FreeableMemory alarm"
    type        = number
    default     = 500 * 1024 * 1024 # 500 MB
}

# ================================================================
# Valkey Data Setting variables
# ================================================================
variable "valkey_data_setting_ingress_rules" {
  description = "Ingress rules for Valkey Data Setting (EC2 + ECS security groups)"
  type = list(object({
    security_group_id        = optional(string, null)
    cidr_blocks              = optional(list(string), null)
    description              = string
  }))
  default = []
}

variable "valkey_data_setting_node_type" {
  description = "Instance class for Valkey Data Setting nodes"
  type        = string
  default     = "cache.t4g.micro"
}

variable "valkey_data_setting_num_cache_nodes" {
  description = "Number of cache nodes for Valkey Data Setting (≥2 enables read replicas)"
  type        = number
  default     = 2
}

variable "valkey_data_setting_engine_version" {
  description = "Valkey engine version for Data Setting cluster"
  type        = string
  default     = "8.2"
}

variable "valkey_data_setting_multi_az_enabled" {
  description = "Enable Multi-AZ for Valkey Data Setting"
  type        = bool
  default     = true
}

variable "valkey_data_setting_at_rest_encryption_enabled" {
  description = "Enable encryption at rest for Valkey Data Setting"
  type        = bool
  default     = true
}

variable "valkey_data_setting_transit_encryption_enabled" {
  description = "Enable encryption in transit for Valkey Data Setting"
  type        = bool
  default     = true
}

variable "valkey_data_setting_snapshot_retention_limit" {
  description = "Snapshot retention days for Valkey Data Setting"
  type        = number
  default     = 7
}

variable "valkey_data_setting_snapshot_window" {
  description = "Snapshot window for Valkey Data Setting"
  type        = string
  default     = "03:00-04:00"
}

variable "valkey_data_setting_maintenance_window" {
  description = "Maintenance window for Valkey Data Setting"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "valkey_data_setting_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Valkey Data Setting"
  type        = bool
  default     = true
}

variable "valkey_data_setting_alarm_actions" {
  description = "SNS topic ARNs for Valkey Data Setting CloudWatch alarms"
  type        = list(string)
  default     = []
}

variable "valkey_data_setting_memory_alarm_threshold" {
  description = "FreeableMemory alarm threshold (bytes) for Valkey Data Setting"
  type        = number
  default     = 100 * 1024 * 1024 # 100 MB
}

# Monthly Adding Site Tables Producer
variable "monthly_adding_site_tables_producers" {
  description = "Map of monthly-adding-site-tables-producer module instances"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Role
    lambda_inline_policies     = optional(map(string), {})

    # Optional VPC
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger monthly-adding-site-tables-producer on a schedule")
    schedule_expression          = string
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})
    scheduler_inline_policies    = optional(map(string), {})

    schedule_retry_policy        = optional(object({
      maximum_event_age_in_seconds = optional(number, 900)
      maximum_retry_attempts       = optional(number, 3)
    }))

    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# Monthly Adding Site Tables Consumer (Lambda)
variable "monthly_adding_site_tables_consumer" {
  description = "Configuration for monthly-adding-site-tables-consumer"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies     = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # Step Function Configuration
    step_function_name            = string
    step_function_inline_policies = optional(map(string), {})

    # SNS Configuration
    sns_topic_name           = string
    sns_display_name         = string
    sns_subscription_emails  = list(string)
    
    # Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger monthly-adding-site-tables-consumer on a schedule")
    schedule_expression          = string
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})
    scheduler_inline_policies    = optional(map(string), {})
    schedule_retry_policy        = optional(object({
      maximum_event_age_in_seconds = optional(number, 900)
      maximum_retry_attempts       = optional(number, 3)
    }))
    
    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# Delete heat map cache (Lambda + EventBridge Scheduler)
variable "delete_heat_map_cache" {
  description = "Configuration for delete_heat_map_cache"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger delete_heat_map_cache on a schedule")
    schedule_expression          = optional(string, "cron(0 0 1 * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# Delete old data heat map (Lambda + EventBridge Scheduler)
variable "delete_old_data_heat_map" {
  description = "Configuration for delete_old_data_heat_map"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger delete_old_data_heat_map on a schedule")
    schedule_expression          = optional(string, "cron(0 0 1 * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# Monthly Reset Limit (Lambda + EventBridge Scheduler)
variable "monthly_reset_limit" {
  description = "Configuration for monthly_reset_limit"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger monthly_reset_limit on a schedule")
    schedule_expression          = optional(string, "cron(0 0 1 * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# CheckLimit (Lambda + EventBridge Scheduler)
variable "check_limit" {
  description = "Configuration for check limit"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger check-limit on a schedule")
    schedule_expression          = optional(string, "cron(30 * * * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# Move Data to MySQL (Lambda + EventBridge Scheduler) - Connects to RDS and Valkey
variable "move_data_to_mysql" {
  description = "Configuration for move-data-to-mysql Lambda function"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 1024)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 90)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group    = optional(bool, false)
    rds_security_group_id    = optional(string, null)
    smg_end_point_sg_id      = optional(string, null)
    valkey_security_group_id = optional(string, null)
    valkey_port              = optional(number, 6379)

    # EventBridge Scheduler (optional)
    schedule_name                = optional(string, null)
    schedule_description         = optional(string, "Trigger move-data-to-mysql on a schedule")
    schedule_expression          = optional(string, "cron(5 * * * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, null)                     # e.g., { action = "move" }

    # Second EventBridge Scheduler (optional) for missing data
    schedule_missing_name                = optional(string, null)          # e.g., "move_missing_data_to_mysql"
    schedule_missing_description         = optional(string, "Trigger move-data-to-mysql (missing) on a schedule")
    schedule_missing_expression          = optional(string, "cron(45 * * * ? *)")
    schedule_missing_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_missing_enabled             = optional(bool, true)
    schedule_missing_input               = optional(any, null)             # e.g., { action = "move_missing" }

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = optional(object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    }), {
      maximum_event_age_in_seconds = 900
      maximum_retry_attempts       = 3
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}


# Auto delete site heatmap (Lambda + EventBridge Scheduler)
variable "auto_delete_site_heatmap" {
  description = "Configuration for auto_delete_site_heatmap"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Auto-create if null)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Trigger auto_delete_site_heatmap on a schedule")
    schedule_expression          = optional(string, "cron(0 1 * * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Auto-create if null)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# ================================================================
# Daily Inactive Request Update
# ================================================================
variable "daily_inactive_request_update" {
  description = "Configuration for daily_inactive_request_update"
  type = object({
    # Lambda
    lambda_function_name         = string
    lambda_handler               = optional(string, "lambda_function.lambda_handler")
    lambda_runtime               = optional(string, "python3.11")
    lambda_timeout               = optional(number, 900)
    lambda_memory_size           = optional(number, 256)
    lambda_architectures         = optional(list(string), ["x86_64"])
    lambda_environment_variables = optional(map(string), {})
    lambda_log_retention_in_days = optional(number, 7)
    lambda_alias                 = optional(string, null)

    # Lambda IAM Role (Optional inline policies if needed)
    lambda_inline_policies = optional(map(string), {})

    # VPC Configuration
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    create_security_group = optional(bool, false)
    rds_security_group_id = optional(string, null)
    smg_end_point_sg_id   = optional(string, null)

    # EventBridge Scheduler
    schedule_name                = string
    schedule_description         = optional(string, "Daily Inactive Request Update")
    schedule_expression          = optional(string, "cron(1 0 * * ? *)")
    schedule_expression_timezone = optional(string, "Asia/Tokyo")
    schedule_enabled             = optional(bool, true)
    schedule_input               = optional(any, {})

    # Scheduler IAM Role (Optional inline policies if needed)
    scheduler_inline_policies = optional(map(string), {})

    schedule_retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })

    # Tags
    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# ================================================================
# CloudWatch Alarms
# ================================================================
variable "cloudwatch_alarms" {
  description = "Configuration object for CloudWatch alarms. Set to null to disable."
  type = object({
    name = optional(string, null) # defaults to project_name-environment

    alarms = optional(map(object({
      namespace           = optional(string, null)
      metric_name         = optional(string, null)
      dimensions          = optional(map(string), {})
      metric_queries      = optional(list(object({
        id          = string
        expression  = optional(string, null)
        label       = optional(string, null)
        return_data = optional(bool, false)
        metric = optional(object({
          namespace   = string
          metric_name = string
          period      = number
          stat        = string
          unit        = optional(string, null)
        }), null)
      })), [])
      threshold           = number
      comparison_operator = optional(string, "GreaterThanOrEqualToThreshold")
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
      datapoints_to_alarm = optional(number, null)
      statistic           = optional(string, "Average")
      extended_statistic  = optional(string, null)
      treat_missing_data  = optional(string, "missing")
      ok_actions_enabled  = optional(bool, false)
      alarm_description   = optional(string, "")
    })), {})

    notification = optional(object({
      existing_sns_topic_arns = optional(string, null)
    }), {})

    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# ================================================================
# ECR Repositories
# ================================================================
variable "ecr_repositories" {
  description = "Map of ECR repositories to create. Key is used as the module identifier, value is the repository name."
  type        = map(string)
}

# ================================================================
# HeatmapPopupNetty – ECS + ALB
# ================================================================
variable "heatmap_popup_netty" {
  description = "Configuration for heatmap-popup-netty ECS Fargate service (Netty HTTP server, port 8080)"
  type = object({
    # Network
    vpc_id             = string
    public_subnet_ids  = optional(list(string), [])
    private_subnet_ids = list(string)
    assign_public_ip   = optional(bool, false)

    # ALB mode
    create_alb                     = optional(bool, true)
    external_target_group_arn      = optional(string, "")
    external_alb_security_group_id = optional(string, "")

    # ALB configuration (only used when create_alb = true)
    alb_ingress_rules = optional(list(object({
      description     = string
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = optional(list(string), [])
      security_groups = optional(list(string), [])
    })), [])

    # SSL (only used when create_alb = true; leave empty for HTTP-only)
    certificate_arn = optional(string, "")

    # Health check: GET / → HTTP 200 in Netty (WebServerHandler "/" route)
    health_check_path = optional(string, "/")

    # ECS container / task
    # container_port must match SSM /heatmap/popupnetty/server/port
    ecs_config = optional(object({
      container_name     = optional(string, "heatmap-popup-netty")
      container_port     = optional(number, 8080)
      cpu                = optional(number, 512)
      memory             = optional(number, 1024)
      log_retention_days = optional(number, 7)
    }), {})

    image_tag = optional(string, "latest")
    java_opts = optional(string, "-Xms128m -XX:MaxRAMPercentage=55.0 -XX:+UseContainerSupport -XX:+UseG1GC -XX:MaxGCPauseMillis=200")

    # Auto Scaling
    min_capacity     = optional(number, 1)
    max_capacity     = optional(number, 5)
    desired_capacity = optional(number, 1)
    cpu_threshold    = optional(number, 60)
    memory_threshold = optional(number, 70)

    # Monitoring
    task_count_alarm_threshold = optional(number, 6)
    enable_cloudwatch_alarms   = optional(bool, true)
    sns_topic_alarm_arn        = optional(string, "")

    # Main Valkey SG (no RDS needed for Netty)
    existing_valkey_security_group_id = optional(string, "")
    valkey_port_range                 = optional(number, 6379)

    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# ================================================================
# HeatmapJapanNetty – ECS + ALB
# ================================================================
variable "heatmap_japan_netty" {
  description = "Configuration for heatmap-japan-netty ECS Fargate service (WebSocket data ingestion, port 8000)"
  type = object({
    # Network
    vpc_id             = string
    public_subnet_ids  = optional(list(string), [])
    private_subnet_ids = list(string)
    assign_public_ip   = optional(bool, false)

    # ALB mode
    # create_alb = true  (prod) → create dedicated ALB named heatmap-netty-alb
    # create_alb = false (dev)  → use shared ALB with external_target_group_arn
    create_alb                     = optional(bool, true)
    external_target_group_arn      = optional(string, "")
    external_alb_security_group_id = optional(string, "")

    # ALB configuration (only used when create_alb = true)
    alb_ingress_rules = optional(list(object({
      description     = string
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = optional(list(string), [])
      security_groups = optional(list(string), [])
    })), [])

    # SSL (only used when create_alb = true; leave empty for HTTP-only)
    certificate_arn = optional(string, "")

    # false → HTTP:80 forwards to the target group (ws:// clients on port 80 keep working)
    # true  → HTTP:80 returns 301 to HTTPS
    http_redirect_to_https = optional(bool, false)

    # Health check path for ALB target group and container health check
    health_check_path = optional(string, "/")

    # ECS container / task
    # container_port must match SSM /heatmap/netty/server/port
    ecs_config = optional(object({
      container_name     = optional(string, "heatmap-japan-netty")
      container_port     = optional(number, 8000)
      cpu                = optional(number, 512)
      memory             = optional(number, 1024)
      log_retention_days = optional(number, 7)
    }), {})

    image_tag = optional(string, "latest")
    java_opts = optional(string, "-Xms128m -XX:MaxRAMPercentage=55.0 -XX:+UseContainerSupport -XX:+UseG1GC -XX:MaxGCPauseMillis=200")

    # Auto Scaling
    min_capacity     = optional(number, 1)
    max_capacity     = optional(number, 5)
    desired_capacity = optional(number, 1)
    cpu_threshold    = optional(number, 60)
    memory_threshold = optional(number, 70)

    # Monitoring
    task_count_alarm_threshold = optional(number, 6)
    enable_cloudwatch_alarms   = optional(bool, true)
    alarm_actions_enabled = optional(bool, true)
    sns_topic_alarm_arn   = optional(string, "")

    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}

# ================================================================
# HeatmapPopupConsole – ECS + ALB
# ================================================================
variable "heatmap_popup_console" {
  description = "Configuration for heatmap-popup-console ECS Fargate service with ALB"
  type = object({
    # Network
    vpc_id             = string
    public_subnet_ids  = optional(list(string), [])
    private_subnet_ids = list(string)

    # ECS network mode
    assign_public_ip = optional(bool, false)

    # ── ALB Mode ──────────────────────────────────────────────────────
    # create_alb = true  (default) → create a brand-new ALB + TG (prod)
    # create_alb = false            → no ALB/TG, ECS runs standalone (dev)
    create_alb = optional(bool, true)

    # External target group ARN (used when create_alb = false but ECS still needs a load_balancer block)
    external_target_group_arn      = optional(string, "")
    external_alb_security_group_id = optional(string, "")


    # ALB configuration (only used when create_alb = true)
    alb_ingress_rules = optional(list(object({
      description     = string
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = optional(list(string), [])
      security_groups = optional(list(string), [])
    })), [])

    # SSL (only used when create_alb = true)
    certificate_arn = optional(string, "")

    # Health check path for both the ALB target group and container health check.
    health_check_path = optional(string, "/actuator/health")

    # ECS container / task
    ecs_config = optional(object({
      container_name     = optional(string, "heatmap-popup-console")
      container_port     = optional(number, 8001)
      cpu                = optional(number, 512)
      memory             = optional(number, 1024)
      log_retention_days = optional(number, 7)
    }), {})

    image_tag = optional(string, "latest")
    java_opts = optional(string, "-Xms512m -XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport -XX:+UseG1GC -XX:MaxGCPauseMillis=200")

    # Auto Scaling
    min_capacity     = optional(number, 1)
    max_capacity     = optional(number, 5)
    desired_capacity = optional(number, 2)
    cpu_threshold    = optional(number, 70)
    memory_threshold = optional(number, 70)

    # Monitoring
    task_count_alarm_threshold = optional(number, 5)
    sns_topic_alarm_arn        = optional(string, "")

    # Existing infrastructure SGs (optional)
    existing_rds_security_group_id    = optional(string, "")
    existing_valkey_security_group_id = optional(string, "")

    # S3 bucket for popup image upload/download
    s3_bucket_name = optional(string, "")
    s3_rds_bucket_name = optional(string, "")

    valkey_port_range = optional(number, 6379)

    tags = optional(map(string), {})
  })

  nullable = true
  default  = null
}