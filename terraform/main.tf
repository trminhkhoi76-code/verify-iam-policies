terraform {
  required_version = ">= 1.8.0"
  
  # Updated for testing workflow
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Stage       = var.environment
      ManagedBy   = "terraform"
      ServiceName = "Heatmap"
      FeatureName = "Heatmap"
    }
  }

  ignore_tags {
    keys = ["awsApplication"]
  }
}

# Shared IAM Role for All Lambda Functions
module "shared_lambda_role" {
  source = "./modules/iam-role"

  role_name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policies = merge(
    try(var.monthly_adding_site_tables_producers.lambda_inline_policies, {}),
    try(var.monthly_adding_site_tables_consumer.lambda_inline_policies, {}),
    try(var.monthly_reset_limit.lambda_inline_policies, {}),
    try(var.auto_delete_site_heatmap.lambda_inline_policies, {}),
    try(var.move_data_to_mysql.lambda_inline_policies, {}),
    try(var.daily_inactive_request_update.lambda_inline_policies, {})
  )
  
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]

  tags = var.tags
}

# Shared IAM Role for All Step Functions
module "shared_step_functions_role" {
  source = "./modules/iam-role"

  role_name = "${var.project_name}-step-functions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policies = merge(
    try(var.monthly_adding_site_tables_consumer.step_function_inline_policies, {})
  )

  tags = var.tags
}

# Shared IAM Role for All EventBridge Schedulers
module "shared_scheduler_role" {
  source = "./modules/iam-role"

  role_name = "${var.project_name}-scheduler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policies = merge(
    try(var.monthly_adding_site_tables_producers.scheduler_inline_policies, {}),
    try(var.monthly_adding_site_tables_consumer.scheduler_inline_policies, {}),
    try(var.delete_heat_map_cache.scheduler_inline_policies, {}), 
    try(var.delete_old_data_heat_map.scheduler_inline_policies, {}),
    try(var.check_limit.scheduler_inline_policies, {}),
    try(var.monthly_reset_limit.scheduler_inline_policies, {}),
    try(var.auto_delete_site_heatmap.scheduler_inline_policies, {}),
    try(var.move_data_to_mysql.scheduler_inline_policies, {}),
    try(var.daily_inactive_request_update.scheduler_inline_policies, {})
  )

  tags = var.tags
}

# Valkey Module
module "valkey" {
  source = "./modules/valkey"

  cluster_name              = "heatmap-japan-valkey"
  environment               = var.environment
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  ingress_rules = concat(var.valkey_ingress_rules, length(module.heatmap_japan_netty) > 0 ? [{
    security_group_id = module.heatmap_japan_netty[0].ecs_security_group_id
    description        = "Heatmap Japan Netty ECS Fargate tasks"
  }] : [])

  # Valkey configuration
  node_type           = var.valkey_node_type
  num_cache_nodes     = var.valkey_num_cache_nodes
  engine_version      = var.valkey_engine_version
  multi_az_enabled    = var.valkey_multi_az_enabled
  
  # Security
  at_rest_encryption_enabled = var.valkey_at_rest_encryption_enabled
  transit_encryption_enabled = var.valkey_transit_encryption_enabled
  
  # Backup
  snapshot_retention_limit = var.valkey_snapshot_retention_limit
  snapshot_window         = var.valkey_snapshot_window
  maintenance_window      = var.valkey_maintenance_window
  
  # Monitoring
  enable_cloudwatch_alarms = var.valkey_enable_cloudwatch_alarms
  alarm_actions            = var.valkey_alarm_actions
  memory_alarm_threshold   = var.valkey_memory_alarm_threshold
  
  tags = var.tags
}

# Valkey Data Setting Module
module "valkey_data_setting" {
  source = "./modules/valkey"

  cluster_name = "heatmap-japan-valkey-data-setting"
  environment  = var.environment
  vpc_id       = var.vpc_id
  subnet_ids   = var.subnet_ids
  ingress_rules = concat(var.valkey_data_setting_ingress_rules, length(module.heatmap_japan_netty) > 0 ? [{
    security_group_id = module.heatmap_japan_netty[0].ecs_security_group_id
    description        = "Heatmap Japan Netty ECS Fargate tasks"
  }] : [])

  # Valkey configuration
  node_type       = var.valkey_data_setting_node_type
  num_cache_nodes = var.valkey_data_setting_num_cache_nodes
  engine_version  = var.valkey_data_setting_engine_version
  multi_az_enabled = var.valkey_data_setting_multi_az_enabled

  # Security
  at_rest_encryption_enabled = var.valkey_data_setting_at_rest_encryption_enabled
  transit_encryption_enabled = var.valkey_data_setting_transit_encryption_enabled

  # Backup
  snapshot_retention_limit = var.valkey_data_setting_snapshot_retention_limit
  snapshot_window          = var.valkey_data_setting_snapshot_window
  maintenance_window       = var.valkey_data_setting_maintenance_window

  # Parameter group
  create_parameter_group = true

  # Monitoring
  enable_cloudwatch_alarms = var.valkey_data_setting_enable_cloudwatch_alarms
  alarm_actions            = var.valkey_data_setting_alarm_actions
  memory_alarm_threshold   = var.valkey_data_setting_memory_alarm_threshold

  tags = var.tags
}

# Monthly Adding Site Tables Producer (Lambda + EventBridge Scheduler)
module "monthly_adding_site_tables_producer" {
  source   = "./modules/monthly-adding-site-tables-producer"

  project_name = var.project_name

  lambda_function_name         = var.monthly_adding_site_tables_producers.lambda_function_name
  lambda_handler               = var.monthly_adding_site_tables_producers.lambda_handler
  lambda_runtime               = var.monthly_adding_site_tables_producers.lambda_runtime
  lambda_timeout               = var.monthly_adding_site_tables_producers.lambda_timeout
  lambda_memory_size           = var.monthly_adding_site_tables_producers.lambda_memory_size
  lambda_architectures         = var.monthly_adding_site_tables_producers.lambda_architectures
  lambda_environment_variables = var.monthly_adding_site_tables_producers.lambda_environment_variables
  lambda_log_retention_in_days = var.monthly_adding_site_tables_producers.lambda_log_retention_in_days
  lambda_alias                 = var.monthly_adding_site_tables_producers.lambda_alias
  # Role
  lambda_role_arn              = module.shared_lambda_role.role_arn

  vpc_config                   = try(var.monthly_adding_site_tables_producers.vpc_config, null)
  create_security_group        = var.monthly_adding_site_tables_producers.create_security_group
  rds_security_group_id        = var.monthly_adding_site_tables_producers.rds_security_group_id
  smg_end_point_sg_id          = var.monthly_adding_site_tables_producers.smg_end_point_sg_id

  schedule_name                = var.monthly_adding_site_tables_producers.schedule_name
  schedule_description         = var.monthly_adding_site_tables_producers.schedule_description
  schedule_expression          = var.monthly_adding_site_tables_producers.schedule_expression
  schedule_expression_timezone = var.monthly_adding_site_tables_producers.schedule_expression_timezone
  schedule_enabled             = var.monthly_adding_site_tables_producers.schedule_enabled
  schedule_input               = var.monthly_adding_site_tables_producers.schedule_input
  scheduler_role_arn           = module.shared_scheduler_role.role_arn
  schedule_retry_policy        = var.monthly_adding_site_tables_producers.schedule_retry_policy

  tags = merge(var.tags, try(var.monthly_adding_site_tables_producers.tags, {}))
}

# Monthly Reset Limit (Lambda + EventBridge Scheduler)
module "monthly_reset_limit" {
  source = "./modules/monthly-reset-limit"

  count = var.monthly_reset_limit == null ? 0 : 1

  project_name = var.project_name

  # Lambda configuration
  lambda_function_name         = var.monthly_reset_limit.lambda_function_name
  lambda_handler               = var.monthly_reset_limit.lambda_handler
  lambda_runtime               = var.monthly_reset_limit.lambda_runtime
  lambda_timeout               = var.monthly_reset_limit.lambda_timeout
  lambda_memory_size           = var.monthly_reset_limit.lambda_memory_size
  lambda_architectures         = var.monthly_reset_limit.lambda_architectures
  lambda_environment_variables = var.monthly_reset_limit.lambda_environment_variables
  lambda_log_retention_in_days = var.monthly_reset_limit.lambda_log_retention_in_days
  lambda_alias                 = var.monthly_reset_limit.lambda_alias

  # IAM Roles
  lambda_role_arn   = module.shared_lambda_role.role_arn
  scheduler_role_arn = module.shared_scheduler_role.role_arn

  # Networking
  vpc_config            = try(var.monthly_reset_limit.vpc_config, null)
  create_security_group = var.monthly_reset_limit.create_security_group

  # Scheduler configuration
  schedule_name                = var.monthly_reset_limit.schedule_name
  schedule_description         = var.monthly_reset_limit.schedule_description
  schedule_expression          = var.monthly_reset_limit.schedule_expression
  schedule_expression_timezone = var.monthly_reset_limit.schedule_expression_timezone
  schedule_enabled             = var.monthly_reset_limit.schedule_enabled
  schedule_input               = var.monthly_reset_limit.schedule_input
  schedule_retry_policy        = var.monthly_reset_limit.schedule_retry_policy

  tags = merge(var.tags, try(var.monthly_reset_limit.tags, {}))
}

# Monthly Adding Site Tables Consumer (Lambda)
module "monthly_adding_site_tables_consumer" {
  source = "./modules/monthly-adding-site-tables-consumer"
  count  = var.monthly_adding_site_tables_consumer == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.monthly_adding_site_tables_consumer.lambda_function_name
  lambda_handler               = var.monthly_adding_site_tables_consumer.lambda_handler
  lambda_runtime               = var.monthly_adding_site_tables_consumer.lambda_runtime
  lambda_timeout               = var.monthly_adding_site_tables_consumer.lambda_timeout
  lambda_memory_size           = var.monthly_adding_site_tables_consumer.lambda_memory_size
  lambda_architectures         = var.monthly_adding_site_tables_consumer.lambda_architectures
  lambda_environment_variables = var.monthly_adding_site_tables_consumer.lambda_environment_variables
  lambda_log_retention_in_days = var.monthly_adding_site_tables_consumer.lambda_log_retention_in_days

  lambda_role_arn              = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.monthly_adding_site_tables_consumer.vpc_config, null)
  create_security_group = var.monthly_adding_site_tables_consumer.create_security_group
  rds_security_group_id = var.monthly_adding_site_tables_consumer.rds_security_group_id
  smg_end_point_sg_id   = var.monthly_adding_site_tables_consumer.smg_end_point_sg_id
  
  # Step Function
  step_function_name      = var.monthly_adding_site_tables_consumer.step_function_name
  step_function_role_arn  = module.shared_step_functions_role.role_arn
  
  # SNS Configuration
  sns_topic_name    = var.monthly_adding_site_tables_consumer.sns_topic_name
  sns_display_name  = var.monthly_adding_site_tables_consumer.sns_display_name
  sns_subscription_emails = var.monthly_adding_site_tables_consumer.sns_subscription_emails
  
  # EventBridge Scheduler
  schedule_name                = var.monthly_adding_site_tables_consumer.schedule_name
  schedule_description         = var.monthly_adding_site_tables_consumer.schedule_description
  schedule_expression          = var.monthly_adding_site_tables_consumer.schedule_expression
  schedule_expression_timezone = var.monthly_adding_site_tables_consumer.schedule_expression_timezone
  schedule_enabled             = var.monthly_adding_site_tables_consumer.schedule_enabled
  schedule_input               = var.monthly_adding_site_tables_consumer.schedule_input
  scheduler_role_arn           = module.shared_scheduler_role.role_arn
  schedule_retry_policy        = var.monthly_adding_site_tables_consumer.schedule_retry_policy

  tags = merge(var.tags, try(var.monthly_adding_site_tables_consumer.tags, {}))
}

# Delete heat map cache
module "delete_heat_map_cache" {
  source = "./modules/delete-heat-map-cache"
  count  = var.delete_heat_map_cache == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.delete_heat_map_cache.lambda_function_name
  lambda_handler               = var.delete_heat_map_cache.lambda_handler
  lambda_runtime               = var.delete_heat_map_cache.lambda_runtime
  lambda_timeout               = var.delete_heat_map_cache.lambda_timeout
  lambda_memory_size           = var.delete_heat_map_cache.lambda_memory_size
  lambda_architectures         = var.delete_heat_map_cache.lambda_architectures
  lambda_environment_variables = var.delete_heat_map_cache.lambda_environment_variables
  lambda_log_retention_in_days = var.delete_heat_map_cache.lambda_log_retention_in_days
  lambda_alias                 = var.delete_heat_map_cache.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.delete_heat_map_cache.vpc_config, null)
  create_security_group = var.delete_heat_map_cache.create_security_group
  rds_security_group_id = var.delete_heat_map_cache.rds_security_group_id
  smg_end_point_sg_id   = var.delete_heat_map_cache.smg_end_point_sg_id

  # EventBridge Scheduler
  schedule_name                = var.delete_heat_map_cache.schedule_name
  schedule_description         = var.delete_heat_map_cache.schedule_description
  schedule_expression          = var.delete_heat_map_cache.schedule_expression
  schedule_expression_timezone = var.delete_heat_map_cache.schedule_expression_timezone
  schedule_enabled             = var.delete_heat_map_cache.schedule_enabled
  schedule_input               = var.delete_heat_map_cache.schedule_input

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.delete_heat_map_cache.schedule_retry_policy

  tags = merge(var.tags, try(var.delete_heat_map_cache.tags, {}))
}

# Delete old data heat map
module "delete_old_data_heat_map" {
  source = "./modules/delete-old-data-heat-map"
  count  = var.delete_old_data_heat_map == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.delete_old_data_heat_map.lambda_function_name
  lambda_handler               = var.delete_old_data_heat_map.lambda_handler
  lambda_runtime               = var.delete_old_data_heat_map.lambda_runtime
  lambda_timeout               = var.delete_old_data_heat_map.lambda_timeout
  lambda_memory_size           = var.delete_old_data_heat_map.lambda_memory_size
  lambda_architectures         = var.delete_old_data_heat_map.lambda_architectures
  lambda_environment_variables = var.delete_old_data_heat_map.lambda_environment_variables
  lambda_log_retention_in_days = var.delete_old_data_heat_map.lambda_log_retention_in_days
    lambda_alias               = var.delete_old_data_heat_map.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.delete_old_data_heat_map.vpc_config, null)
  create_security_group = var.delete_old_data_heat_map.create_security_group
  rds_security_group_id = var.delete_old_data_heat_map.rds_security_group_id
  smg_end_point_sg_id   = var.delete_old_data_heat_map.smg_end_point_sg_id

  # EventBridge Scheduler
  schedule_name                = var.delete_old_data_heat_map.schedule_name
  schedule_description         = var.delete_old_data_heat_map.schedule_description
  schedule_expression          = var.delete_old_data_heat_map.schedule_expression
  schedule_expression_timezone = var.delete_old_data_heat_map.schedule_expression_timezone
  schedule_enabled             = var.delete_old_data_heat_map.schedule_enabled
  schedule_input               = var.delete_old_data_heat_map.schedule_input

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.delete_old_data_heat_map.schedule_retry_policy

  tags = merge(var.tags, try(var.delete_old_data_heat_map.tags, {}))
}

# Check limit
module "check_limit" {
  source = "./modules/check-limit"
  count  = var.check_limit == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.check_limit.lambda_function_name
  lambda_handler               = var.check_limit.lambda_handler
  lambda_runtime               = var.check_limit.lambda_runtime
  lambda_timeout               = var.check_limit.lambda_timeout
  lambda_memory_size           = var.check_limit.lambda_memory_size
  lambda_architectures         = var.check_limit.lambda_architectures
  lambda_environment_variables = var.check_limit.lambda_environment_variables
  lambda_log_retention_in_days = var.check_limit.lambda_log_retention_in_days
  lambda_alias                 = var.check_limit.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.check_limit.vpc_config, null)
  create_security_group = var.check_limit.create_security_group
  rds_security_group_id = var.check_limit.rds_security_group_id
  smg_end_point_sg_id   = var.check_limit.smg_end_point_sg_id

  # EventBridge Scheduler
  schedule_name                = var.check_limit.schedule_name
  schedule_description         = var.check_limit.schedule_description
  schedule_expression          = var.check_limit.schedule_expression
  schedule_expression_timezone = var.check_limit.schedule_expression_timezone
  schedule_enabled             = var.check_limit.schedule_enabled
  schedule_input               = var.check_limit.schedule_input

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.check_limit.schedule_retry_policy

  tags = merge(var.tags, try(var.check_limit.tags, {}))
}

# Move Data to MySQL (Lambda + EventBridge Scheduler) - Connects to RDS and Valkey
module "move_data_to_mysql" {
  source = "./modules/move-data-to-mysql"
  count  = var.move_data_to_mysql == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.move_data_to_mysql.lambda_function_name
  lambda_handler               = var.move_data_to_mysql.lambda_handler
  lambda_runtime               = var.move_data_to_mysql.lambda_runtime
  lambda_timeout               = var.move_data_to_mysql.lambda_timeout
  lambda_memory_size           = var.move_data_to_mysql.lambda_memory_size
  lambda_architectures         = var.move_data_to_mysql.lambda_architectures
  lambda_environment_variables = var.move_data_to_mysql.lambda_environment_variables
  lambda_log_retention_in_days = var.move_data_to_mysql.lambda_log_retention_in_days
  lambda_alias                 = var.move_data_to_mysql.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config               = try(var.move_data_to_mysql.vpc_config, null)
  create_security_group    = var.move_data_to_mysql.create_security_group
  rds_security_group_id    = var.move_data_to_mysql.rds_security_group_id
  smg_end_point_sg_id      = var.move_data_to_mysql.smg_end_point_sg_id
  valkey_security_group_id = var.move_data_to_mysql.valkey_security_group_id
  valkey_port              = var.move_data_to_mysql.valkey_port

  # EventBridge Scheduler (optional)
  schedule_name                = var.move_data_to_mysql.schedule_name
  schedule_description         = var.move_data_to_mysql.schedule_description
  schedule_expression          = var.move_data_to_mysql.schedule_expression
  schedule_expression_timezone = var.move_data_to_mysql.schedule_expression_timezone
  schedule_enabled             = var.move_data_to_mysql.schedule_enabled
  schedule_input               = var.move_data_to_mysql.schedule_input

  # Second EventBridge Scheduler (optional) for missing data
  schedule_missing_name                = try(var.move_data_to_mysql.schedule_missing_name, null)
  schedule_missing_description         = try(var.move_data_to_mysql.schedule_missing_description, null)
  schedule_missing_expression          = try(var.move_data_to_mysql.schedule_missing_expression, null)
  schedule_missing_expression_timezone = try(var.move_data_to_mysql.schedule_missing_expression_timezone, null)
  schedule_missing_enabled             = try(var.move_data_to_mysql.schedule_missing_enabled, null)
  schedule_missing_input               = try(var.move_data_to_mysql.schedule_missing_input, null)

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.move_data_to_mysql.schedule_retry_policy

  tags = merge(var.tags, try(var.move_data_to_mysql.tags, {}))
}


# Auto delete site heatmap
module "auto_delete_site_heatmap" {
  source = "./modules/auto-delete-site-heatmap"
  count  = var.auto_delete_site_heatmap == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.auto_delete_site_heatmap.lambda_function_name
  lambda_handler               = var.auto_delete_site_heatmap.lambda_handler
  lambda_runtime               = var.auto_delete_site_heatmap.lambda_runtime
  lambda_timeout               = var.auto_delete_site_heatmap.lambda_timeout
  lambda_memory_size           = var.auto_delete_site_heatmap.lambda_memory_size
  lambda_architectures         = var.auto_delete_site_heatmap.lambda_architectures
  lambda_environment_variables = var.auto_delete_site_heatmap.lambda_environment_variables
  lambda_log_retention_in_days = var.auto_delete_site_heatmap.lambda_log_retention_in_days
  lambda_alias                 = var.auto_delete_site_heatmap.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.auto_delete_site_heatmap.vpc_config, null)
  create_security_group = var.auto_delete_site_heatmap.create_security_group
  rds_security_group_id = var.auto_delete_site_heatmap.rds_security_group_id
  smg_end_point_sg_id   = try(var.auto_delete_site_heatmap.smg_end_point_sg_id, null)

  # EventBridge Scheduler
  schedule_name                = var.auto_delete_site_heatmap.schedule_name
  schedule_description         = var.auto_delete_site_heatmap.schedule_description
  schedule_expression          = var.auto_delete_site_heatmap.schedule_expression
  schedule_expression_timezone = var.auto_delete_site_heatmap.schedule_expression_timezone
  schedule_enabled             = var.auto_delete_site_heatmap.schedule_enabled
  schedule_input               = var.auto_delete_site_heatmap.schedule_input

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.auto_delete_site_heatmap.schedule_retry_policy

  tags = merge(var.tags, try(var.auto_delete_site_heatmap.tags, {}))
}


# Daily Inactive Request Update (Lambda + EventBridge Scheduler)
module "daily_inactive_request_update" {
  source = "./modules/daily-inactive-request-update"
  count  = var.daily_inactive_request_update == null ? 0 : 1

  project_name = var.project_name

  lambda_function_name         = var.daily_inactive_request_update.lambda_function_name
  lambda_handler               = var.daily_inactive_request_update.lambda_handler
  lambda_runtime               = var.daily_inactive_request_update.lambda_runtime
  lambda_timeout               = var.daily_inactive_request_update.lambda_timeout
  lambda_memory_size           = var.daily_inactive_request_update.lambda_memory_size
  lambda_architectures         = var.daily_inactive_request_update.lambda_architectures
  lambda_environment_variables = var.daily_inactive_request_update.lambda_environment_variables
  lambda_log_retention_in_days = var.daily_inactive_request_update.lambda_log_retention_in_days
  lambda_alias                 = var.daily_inactive_request_update.lambda_alias

  lambda_role_arn = module.shared_lambda_role.role_arn

  # VPC
  vpc_config            = try(var.daily_inactive_request_update.vpc_config, null)
  create_security_group = var.daily_inactive_request_update.create_security_group
  rds_security_group_id = try(var.daily_inactive_request_update.rds_security_group_id, null)
  smg_end_point_sg_id   = try(var.daily_inactive_request_update.smg_end_point_sg_id, null)

  # EventBridge Scheduler
  schedule_name                = var.daily_inactive_request_update.schedule_name
  schedule_description         = var.daily_inactive_request_update.schedule_description
  schedule_expression          = var.daily_inactive_request_update.schedule_expression
  schedule_expression_timezone = var.daily_inactive_request_update.schedule_expression_timezone
  schedule_enabled             = var.daily_inactive_request_update.schedule_enabled
  schedule_input               = var.daily_inactive_request_update.schedule_input

  scheduler_role_arn    = module.shared_scheduler_role.role_arn
  schedule_retry_policy = var.daily_inactive_request_update.schedule_retry_policy

  tags = merge(var.tags, try(var.daily_inactive_request_update.tags, {}))
}


# ================================================================
# CloudWatch Metric Alarms
# ================================================================
module "cloudwatch_alarms" {
  source = "./modules/cloudwatch-alarm"
  count  = var.cloudwatch_alarms == null ? 0 : 1

  name = coalesce(
    try(var.cloudwatch_alarms.name, null),
    "${var.project_name}-${var.environment}"
  )

  alarms       = coalesce(try(var.cloudwatch_alarms.alarms, null), {})
  notification = coalesce(try(var.cloudwatch_alarms.notification, null), {})

  tags = merge(var.tags, try(var.cloudwatch_alarms.tags, {}))
}


# ================================================================
# ECR Repositories (console, popup, …)
# ================================================================
module "ecr" {
  source   = "./modules/ecr-repository"
  for_each = var.ecr_repositories

  environment     = var.environment
  repository_name = each.value
}

# ================================================================
# ECS Cluster (shared by all ECS services)
# ================================================================
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  cluster_name = "heatmap-japan-cluster"
  aws_region  = var.aws_region
  common_tags = var.tags
}

# ================================================================
# HeatmapPopupConsole – ALB + ECS Task Definition + ECS Service
# ================================================================
module "heatmap_popup_console" {
  source = "./modules/heatmap-popup-console"
  count  = var.heatmap_popup_console != null ? 1 : 0

  common_tags = merge(var.tags, var.heatmap_popup_console.tags)
  aws_region  = var.aws_region

  # Network
  vpc_id             = var.heatmap_popup_console.vpc_id
  public_subnet_ids  = var.heatmap_popup_console.public_subnet_ids
  private_subnet_ids = var.heatmap_popup_console.private_subnet_ids
  assign_public_ip   = var.heatmap_popup_console.assign_public_ip

  # ALB mode
  create_alb                     = var.heatmap_popup_console.create_alb
  external_target_group_arn      = try(var.heatmap_popup_console.external_target_group_arn, "")
  external_alb_security_group_id = try(var.heatmap_popup_console.external_alb_security_group_id, "")

  # ALB config (only used when create_alb = true)
  alb_ingress_rules = var.heatmap_popup_console.alb_ingress_rules
  certificate_arn   = var.heatmap_popup_console.certificate_arn

  # ECS Cluster
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  # Container / Task
  ecs_config         = var.heatmap_popup_console.ecs_config
  ecr_repository_url = module.ecr["popup-console"].repository_url
  image_tag          = var.heatmap_popup_console.image_tag
  java_opts          = var.heatmap_popup_console.java_opts
  health_check_path  = var.heatmap_popup_console.health_check_path

  # Scaling
  min_capacity     = var.heatmap_popup_console.min_capacity
  max_capacity     = var.heatmap_popup_console.max_capacity
  desired_capacity = var.heatmap_popup_console.desired_capacity
  cpu_threshold    = var.heatmap_popup_console.cpu_threshold
  memory_threshold = var.heatmap_popup_console.memory_threshold

  # Monitoring
  task_count_alarm_threshold = var.heatmap_popup_console.task_count_alarm_threshold
  sns_topic_alarm_arn        = try(var.heatmap_popup_console.sns_topic_alarm_arn, "")

  # Existing infrastructure SGs
  existing_rds_security_group_id    = var.heatmap_popup_console.existing_rds_security_group_id
  existing_valkey_security_group_id = var.heatmap_popup_console.existing_valkey_security_group_id

  # S3
  s3_bucket_name = var.heatmap_popup_console.s3_bucket_name
  s3_rds_bucket_name = var.heatmap_popup_console.s3_rds_bucket_name

  valkey_port_range = var.heatmap_popup_console.valkey_port_range
}

# ================================================================
# HeatmapJapanNetty – ALB (prod only) + ECS Task Definition + ECS Service
# ================================================================
module "heatmap_japan_netty" {
  source = "./modules/heatmap-japan-netty"
  count  = var.heatmap_japan_netty != null ? 1 : 0

  common_tags = merge(var.tags, var.heatmap_japan_netty.tags)
  aws_region  = var.aws_region

  # Network
  vpc_id             = var.heatmap_japan_netty.vpc_id
  public_subnet_ids  = var.heatmap_japan_netty.public_subnet_ids
  private_subnet_ids = var.heatmap_japan_netty.private_subnet_ids
  assign_public_ip   = var.heatmap_japan_netty.assign_public_ip

  # ALB mode
  create_alb                     = var.heatmap_japan_netty.create_alb
  external_target_group_arn      = try(var.heatmap_japan_netty.external_target_group_arn, "")
  external_alb_security_group_id = try(var.heatmap_japan_netty.external_alb_security_group_id, "")

  # ALB config (only used when create_alb = true)
  alb_ingress_rules      = var.heatmap_japan_netty.alb_ingress_rules
  certificate_arn        = var.heatmap_japan_netty.certificate_arn
  http_redirect_to_https = var.heatmap_japan_netty.http_redirect_to_https

  # ECS Cluster
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  # Container / Task
  ecr_repository_url = module.ecr["heatmap-netty"].repository_url
  ecs_config         = var.heatmap_japan_netty.ecs_config
  image_tag   = var.heatmap_japan_netty.image_tag
  java_opts          = var.heatmap_japan_netty.java_opts
  health_check_path  = var.heatmap_japan_netty.health_check_path

  # Scaling
  min_capacity     = var.heatmap_japan_netty.min_capacity
  max_capacity     = var.heatmap_japan_netty.max_capacity
  desired_capacity = var.heatmap_japan_netty.desired_capacity
  cpu_threshold    = var.heatmap_japan_netty.cpu_threshold
  memory_threshold = var.heatmap_japan_netty.memory_threshold

  # Monitoring
  task_count_alarm_threshold = var.heatmap_japan_netty.task_count_alarm_threshold
  enable_cloudwatch_alarms   = var.heatmap_japan_netty.enable_cloudwatch_alarms
  alarm_actions_enabled      = var.heatmap_japan_netty.alarm_actions_enabled
  sns_topic_alarm_arn        = try(var.heatmap_japan_netty.sns_topic_alarm_arn, "")
}

# ================================================================
# HeatmapPopupNetty – ALB + ECS Task Definition + ECS Service
# ================================================================
module "heatmap_popup_netty" {
  source = "./modules/heatmap-popup-netty"
  count  = var.heatmap_popup_netty != null ? 1 : 0

  common_tags = merge(var.tags, var.heatmap_popup_netty.tags)
  aws_region  = var.aws_region

  # Network
  vpc_id             = var.heatmap_popup_netty.vpc_id
  public_subnet_ids  = var.heatmap_popup_netty.public_subnet_ids
  private_subnet_ids = var.heatmap_popup_netty.private_subnet_ids
  assign_public_ip   = var.heatmap_popup_netty.assign_public_ip

  # ALB mode
  create_alb                     = var.heatmap_popup_netty.create_alb
  external_target_group_arn      = try(var.heatmap_popup_netty.external_target_group_arn, "")
  external_alb_security_group_id = try(var.heatmap_popup_netty.external_alb_security_group_id, "")

  # ALB config (only used when create_alb = true)
  alb_ingress_rules = var.heatmap_popup_netty.alb_ingress_rules
  certificate_arn   = var.heatmap_popup_netty.certificate_arn

  # ECS Cluster
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  # Container / Task
  ecs_config         = var.heatmap_popup_netty.ecs_config
  ecr_repository_url = module.ecr["popup-netty"].repository_url
  image_tag          = var.heatmap_popup_netty.image_tag
  java_opts          = var.heatmap_popup_netty.java_opts
  health_check_path  = var.heatmap_popup_netty.health_check_path

  # Scaling
  min_capacity     = var.heatmap_popup_netty.min_capacity
  max_capacity     = var.heatmap_popup_netty.max_capacity
  desired_capacity = var.heatmap_popup_netty.desired_capacity
  cpu_threshold    = var.heatmap_popup_netty.cpu_threshold
  memory_threshold = var.heatmap_popup_netty.memory_threshold

  # Monitoring
  task_count_alarm_threshold = var.heatmap_popup_netty.task_count_alarm_threshold
  enable_cloudwatch_alarms   = var.heatmap_popup_netty.enable_cloudwatch_alarms
  sns_topic_alarm_arn        = try(var.heatmap_popup_netty.sns_topic_alarm_arn, "")

  # Existing infrastructure SG
  existing_valkey_security_group_id = var.heatmap_popup_netty.existing_valkey_security_group_id
  valkey_port_range                 = var.heatmap_popup_netty.valkey_port_range
}