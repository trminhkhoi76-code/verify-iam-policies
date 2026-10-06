# ================================================================
# Dev / IAM policy verification stack
# ================================================================

terraform {
  required_version = ">= 1.8.0"

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

# Same default tags as the root module: every create also needs the *:TagResource permission
locals {
  default_tags = {
    Project     = "heatmap-japan"
    Stage       = "dev"
    ManagedBy   = "terraform"
    ServiceName = "Heatmap"
    FeatureName = "Heatmap"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = local.default_tags
  }

  ignore_tags {
    keys = ["awsApplication"]
  }
}

# aws.us_east_1: some AWS-integrated CloudWatch metrics (e.g. AWS/Route53
# HealthCheckStatus) are only ever published to us-east-1, regardless of the
# checked resource's own region. Resources that read them must use this alias.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.default_tags
  }
}

# ================================================================
# Account-specific lookups (no hardcoded account/VPC/subnet/SG IDs)
# ================================================================
# Data sources are read at plan time, so their IDs are known when modules use
# them in count expressions (an SG created in this stack would not be).
variable "vpc_id" {
  description = "VPC to deploy into. null = the account's default VPC."
  type        = string
  default     = null
}

variable "existing_security_group_ids" {
  description = <<-EOT
    SGs of infrastructure outside this Terraform that the stack adds ingress
    rules to: rds, secrets_manager_endpoint. A key left null falls back to the
    VPC's default SG.
  EOT
  type = object({
    rds                      = optional(string)
    secrets_manager_endpoint = optional(string)
  })
  default = {}
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : null
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_security_group" "vpc_default" {
  vpc_id = data.aws_vpc.this.id
  name   = "default"
}

locals {
  aws_region    = "ap-northeast-1"
  aws_shorthand = "${local.aws_region}:${data.aws_caller_identity.current.account_id}"
  environment   = "Dev"
  project_name  = "heatmap-japan"
  tags          = {}

  vpc_id            = data.aws_vpc.this.id
  vpc_cidr_blocks   = [data.aws_vpc.this.cidr_block]
  public_subnet_ids = sort(data.aws_subnets.public.ids)
  rds_sg_id         = coalesce(var.existing_security_group_ids.rds, data.aws_security_group.vpc_default.id)
  smg_sg_id         = coalesce(var.existing_security_group_ids.secrets_manager_endpoint, data.aws_security_group.vpc_default.id)

  # CheckLimit is also the Lambda deployed by terraform-apply-and-deploy.yml
  lambda_name      = "CheckLimit"
  lambda_alias_arn = "arn:aws:lambda:${local.aws_shorthand}:function:${local.lambda_name}:live"
  sfn_name         = "monthly-adding-site-tables-consumer"
  sns_topic_name   = "monthly-adding-site-tables-notifications"
  sns_topic_arn    = "arn:aws:sns:${local.aws_shorthand}:${local.sns_topic_name}"

  # ECS: popup-console (the only service with S3 access + SG rules on existing SGs),
  # on the prod code path (dedicated ALB + listener) so ELB permissions are covered too.
  ecs_name = "heatmap-popup-console"
  ecs_port = 8001
}

# ================================================================
# IAM roles: one per service principal that receives iam:PassRole
# (lambda, states, scheduler here; ecs-tasks in the task definition module)
# ================================================================
module "lambda_role" {
  source = "../../modules/iam-role"

  role_name = "${local.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  inline_policies = {
    "read-rds-secrets" = jsonencode({
      Version   = "2012-10-17"
      Statement = [{ Sid = "ReadRDSSecrets", Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = "arn:aws:secretsmanager:${local.aws_shorthand}:secret:rds/heatmap-db-secret*" }]
    })
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  tags                = local.tags
}

module "step_functions_role" {
  source = "../../modules/iam-role"

  role_name = "${local.project_name}-step-functions-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "states.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  inline_policies = {
    "publish-sns" = jsonencode({
      Version   = "2012-10-17"
      Statement = [{ Sid = "PublishToSNSTopic", Effect = "Allow", Action = ["sns:Publish"], Resource = [local.sns_topic_arn] }]
    })
  }
  tags = local.tags
}

module "scheduler_role" {
  source = "../../modules/iam-role"

  role_name = "${local.project_name}-scheduler-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "scheduler.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  inline_policies = {
    "invoke-lambda" = jsonencode({
      Version   = "2012-10-17"
      Statement = [{ Sid = "InvokeLambdaFunction", Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [local.lambda_alias_arn] }]
    })
  }
  tags = local.tags
}

# ================================================================
# Lambda (log group, own SG, ingress rules on existing SGs, alias)
# + EventBridge Scheduler + log metric filter
# ================================================================
module "lambda" {
  source = "../../modules/lambda-functions"

  # The AWSLambdaVPCAccessExecutionRole attachment must exist before a VPC
  # function is created; role_arn alone only waits for the role itself.
  depends_on = [module.lambda_role]

  project_name  = local.project_name
  function_name = local.lambda_name
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900
  memory_size   = 256
  architectures = ["x86_64"]

  environment_variables = {
    RDS_SECRET_NAME = "rds/heatmap-db-secret"
    REDIS_HOST      = module.valkey.endpoint
    REDIS_PORT      = "6379"
    REDIS_DB        = "0"
  }
  role_arn = module.lambda_role.role_arn

  create_security_group = true
  vpc_config = {
    vpc_id             = local.vpc_id
    subnet_ids         = local.public_subnet_ids
    security_group_ids = []
  }
  rds_security_group_id = local.rds_sg_id
  smg_end_point_sg_id   = local.smg_sg_id

  log_retention_in_days = 7
  tags                  = local.tags
}

module "lambda_schedule" {
  source = "../../modules/eventbridge-scheduler"

  project_name        = local.project_name
  name                = "check-limit-schedule"
  description         = "Trigger check-limit on a schedule"
  schedule_expression = "cron(30 10-19 ? * MON-FRI *)"
  scheduler_role_arn  = module.scheduler_role.role_arn

  target = {
    type  = "lambda"
    arn   = module.lambda.function_arn
    alias = "live"
  }

  retry_policy = {
    maximum_event_age_in_seconds = 900
    maximum_retry_attempts       = 3
  }
}

resource "aws_cloudwatch_log_metric_filter" "lambda_failed" {
  depends_on = [module.lambda] # log group is created by the lambda module

  name           = "Heatmap-${local.environment}-${local.lambda_name}-Failed"
  log_group_name = "/aws/lambda/${local.lambda_name}"
  pattern        = "[level, timestamp, request_id, t1=Parallel*, t2, t3, t4, t5, t6, t7, t8, t9]"

  metric_transformation {
    name          = "ExecutionFailedCount"
    namespace     = "Heatmap/${local.environment}/${local.lambda_name}"
    value         = "$t8"
    default_value = 0
  }
}

# ================================================================
# Step Functions + SNS (topic + email subscription)
# ================================================================
module "step_function" {
  source = "../../modules/step-functions"

  state_name = local.sfn_name
  role_arn   = module.step_functions_role.role_arn
  definition = jsonencode({
    Comment = "Minimal state machine"
    StartAt = "Pass"
    States  = { Pass = { Type = "Pass", End = true } }
  })
  tags = local.tags
}

module "sns_topic" {
  source = "../../modules/sns"

  topic_name          = local.sns_topic_name
  display_name        = "Monthly Adding Site Tables Notifications"
  subscription_emails = ["phamminhluan@fabercompany.co.jp"]
  tags                = local.tags
}

# ================================================================
# Valkey: custom parameter group, slow-log delivery to CloudWatch Logs,
# at-rest encryption, CPU/memory alarms
# ================================================================
module "valkey" {
  source = "../../modules/valkey"

  cluster_name = "heatmap-japan-valkey"
  environment  = "dev"
  vpc_id       = local.vpc_id
  subnet_ids   = local.public_subnet_ids
  ingress_rules = [
    { cidr_blocks = local.vpc_cidr_blocks, description = "VPC CIDR (Faber Admin, Mieruca SEO access)" },
    { security_group_id = module.lambda.security_group_id, description = "Lambda CheckLimit" },
  ]

  node_type                  = "cache.t4g.micro"
  num_cache_nodes            = 1
  engine_version             = "8.2"
  multi_az_enabled           = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
  snapshot_retention_limit   = 1

  create_parameter_group = true

  enable_cloudwatch_alarms = true
  alarm_actions            = [local.sns_topic_arn]
  memory_alarm_threshold   = 100 * 1024 * 1024 # 100 MB

  tags = local.tags
}

# ================================================================
# CloudWatch alarm module ("Heatmap*" alarm names)
# ================================================================
module "cloudwatch_alarms" {
  source = "../../modules/cloudwatch-alarm"

  name = "${local.project_name}-dev"
  alarms = {
    "Heatmap-${local.environment}-Lambda-${local.lambda_name}-Errors-High" = {
      namespace           = "AWS/Lambda"
      metric_name         = "Errors"
      dimensions          = { FunctionName = local.lambda_name }
      threshold           = 2
      period              = 900
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      statistic           = "Sum"
      alarm_description   = "${local.lambda_name} Lambda: >= 2 errors in 15 minutes"
      treat_missing_data  = "notBreaching"
    }
  }
  notification = { existing_sns_topic_arns = local.sns_topic_arn }
  tags         = local.tags
}

# ================================================================
# ECR + ECS cluster + ECS service behind a dedicated ALB
# ================================================================
module "ecr" {
  source = "../../modules/ecr-repository"

  environment     = "dev"
  repository_name = local.ecs_name
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  cluster_name = "heatmap-japan-cluster"
  aws_region   = local.aws_region
  common_tags  = local.tags
}

# ALB SG + ALB + target group + HTTP listener. Ingress limited to the VPC CIDR,
# so the internet-facing ALB is not reachable from outside.
module "alb" {
  source = "../../modules/alb"

  name_prefix       = "heatmap-popup"
  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids
  ingress_rules = [{
    description = "VPC only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_blocks
  }]
  common_tags       = local.tags
  target_port       = local.ecs_port
  health_check_path = "/actuator/health"
  certificate_arn   = "" # an HTTPS listener needs an ACM certificate in this account

  enable_deletion_protection = false
}

# Task definition + log group + execution/task roles + every optional managed
# policy (ECR, Parameter Store, ECS Exec, S3) and their attachments
module "task_definition" {
  source = "../../modules/ecs-task-definition"

  task_family        = local.ecs_name
  aws_region         = local.aws_region
  common_tags        = local.tags
  task_cpu           = 256
  task_memory        = 512
  log_retention_days = 7

  container_definitions = [{
    name         = local.ecs_name
    image        = "${module.ecr.repository_url}:latest"
    essential    = true
    environment  = [{ name = "TZ", value = "Asia/Tokyo" }]
    portMappings = [{ containerPort = local.ecs_port, protocol = "tcp" }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${local.ecs_port}/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
  }]

  parameter_store_prefix = "heatmapjapan-console"
  s3_bucket_name         = "mieruca-heatmap-popup-test"
  s3_rds_bucket_name     = "mieruca-rds-truststore"
}

# ECS SG + log group + service (registered with the ALB target group) + auto
# scaling target + CPU/memory target-tracking policies (which create the
# TargetTracking-service/heatmap-japan-cluster/* alarms).
module "ecs_service" {
  source = "../../modules/ecs-service"

  # ECS rejects a target group that is not yet attached to a load balancer listener
  depends_on = [module.alb]

  service_name = local.ecs_name
  common_tags  = local.tags
  aws_region   = local.aws_region
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  task_definition_arn     = module.task_definition.task_definition_arn
  task_execution_role_arn = module.task_definition.task_execution_role_arn
  container_name          = local.ecs_name
  container_port          = local.ecs_port

  vpc_id                = local.vpc_id
  private_subnet_ids    = local.public_subnet_ids
  public_subnet_ids     = local.public_subnet_ids
  assign_public_ip      = true
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn

  # Cost: the service exists but runs no Fargate task (raise to run one)
  desired_count             = 0
  enable_auto_scaling       = true
  auto_scaling_min_capacity = 0
  auto_scaling_max_capacity = 2
  cpu_target_value          = 70
  memory_target_value       = 70

  # "heatmap-*" alarms are already covered by the Valkey module
  enable_cloudwatch_alarms = false
  sns_topic_alarm_arn      = local.sns_topic_arn
}

# ECS tasks -> existing RDS SG (legacy aws_security_group_rule resource)
resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.ecs_service.ecs_security_group_id
  security_group_id        = local.rds_sg_id
  description              = "MySQL/Aurora from heatmap-japan ECS tasks"
}

# ================================================================
# Route 53 health check + us-east-1 SNS topic and alarm
# ================================================================
resource "aws_sns_topic" "route53_alarm_email_test" {
  provider = aws.us_east_1
  name     = "heatmap-dev-route53-alarm-email-test"
}

# Route 53 is a global service — any provider/region works identically.
resource "aws_route53_health_check" "heatmap_japan_netty_domain" {
  fqdn              = "dev.ntjp.mieru-ca.com"
  type              = "HTTPS"
  port              = 443
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
  regions           = ["us-east-1", "ap-northeast-1", "ap-southeast-1"]

  tags = {
    Name    = "heatmap-japan-netty-domain-health-check"
    Purpose = "monitoring-only"
  }
}

resource "aws_cloudwatch_metric_alarm" "heatmap_japan_netty_domain" {
  provider = aws.us_east_1

  alarm_name          = "Heatmap-Route53HealthCheck-heatmap-japan-netty-domain-Unhealthy"
  alarm_description   = "dev.ntjp.mieru-ca.com failed the external Route 53 ingress health check"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.heatmap_japan_netty_domain.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.route53_alarm_email_test.arn]

  tags = {
    Name = "Heatmap-Route53HealthCheck-heatmap-japan-netty-domain-Unhealthy"
  }
}
