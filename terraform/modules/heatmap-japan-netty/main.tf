# heatmap-japan-netty – ALB (optional) + ECS Task Definition + ECS Service
#
# ECR is managed via root ecr_repositories for_each (key: heatmap-netty).
# Differences from heatmap-popup-netty:
#   - Port 8000 (WebSocket data ingestion, controlled by SSM /heatmap/netty/server/port)
#   - SSM prefix: netty → /heatmap/netty/*
#   - No RDS access (events written to Valkey; Lambda MoveDataToMySQL drains to MySQL)
#   - No S3 access needed
#   - Connects to BOTH Valkey clusters:
#       heatmap-japan-valkey          (primary ingest data, port 6379)
#       heatmap-japan-valkey-data-setting (read-heavy settings data, port varies by env)

locals {
  target_group_arn      = var.create_alb ? module.alb[0].target_group_arn : var.external_target_group_arn
  alb_security_group_id = var.create_alb ? module.alb[0].alb_security_group_id : var.external_alb_security_group_id
}

# ── ALB – only created when create_alb = true (prod) ─────────────────────────
module "alb" {
  source = "../alb"
  count  = var.create_alb ? 1 : 0

  # ALB resource name = "${name_prefix}-alb" = "heatmap-netty-alb"
  name_prefix       = "heatmap-netty"
  vpc_id            = var.vpc_id
  public_subnet_ids = var.public_subnet_ids
  ingress_rules     = var.alb_ingress_rules
  common_tags       = var.common_tags
  target_port       = var.ecs_config.container_port
  health_check_path = var.health_check_path
  certificate_arn   = var.certificate_arn

  # HTTP:80 forwards to the target group instead of 301-ing to HTTPS — the client
  # script still opens plain ws:// connections on port 80, which a redirect would break.
  # Only this ALB (heatmap-netty-alb); popup-netty/popup-console keep the redirect default.
  http_redirect_to_https = var.http_redirect_to_https

  # Must stay above Netty's own 900s IdleStateHandler reader-idle timeout (with margin),
  # otherwise the ALB closes still-active WebSocket connections before Netty does.
  idle_timeout = 960

  enable_deletion_protection = false
}

# ── ECS Task Definition ───────────────────────────────────────────────────────
module "task_definition" {
  source = "../ecs-task-definition"

  task_family        = "heatmap-japan-netty"
  aws_region         = var.aws_region
  common_tags        = var.common_tags
  task_cpu           = var.ecs_config.cpu
  task_memory        = var.ecs_config.memory
  log_retention_days = var.ecs_config.log_retention_days

  container_definitions = [{
    name      = var.ecs_config.container_name
    image     = "${var.ecr_repository_url}:${var.image_tag}"
    essential = true

    environment = [
      { name = "JAVA_OPTS",      value = var.java_opts },
      { name = "TZ",             value = "Asia/Tokyo"  },
      { name = "LOG_TO_STDOUT",  value = "true"        }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"             = "/aws/ecs/task/heatmap-japan-netty"
        "awslogs-region"            = var.aws_region
        "awslogs-stream-prefix"     = var.ecs_config.container_name
        "awslogs-multiline-pattern" = "^\\d{4}/\\d{2}/\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}:\\d{3}\\s+\\[(INFO|ERROR|WARN|DEBUG|TRACE)\\]"
      }
    }

    portMappings = [{
      containerPort = var.ecs_config.container_port
      protocol      = "tcp"
    }]

    ulimits = [
      { name = "nofile", softLimit = 1048576, hardLimit = 1048576 }
    ]

    # WebSocket upgrade handshake on port 8000 also responds to plain HTTP health probes.
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.ecs_config.container_port}${var.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }]

  # SSM: /heatmap/netty/* (server/port, valkey/addresses, etc.)
  parameter_store_prefix = "netty"
}

# ── ECS Service ───────────────────────────────────────────────────────────────
module "ecs_service" {
  source = "../ecs-service"

  service_name = "heatmap-japan-netty"
  common_tags  = var.common_tags
  aws_region   = var.aws_region
  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name

  task_definition_arn     = module.task_definition.task_definition_arn
  task_execution_role_arn = module.task_definition.task_execution_role_arn
  container_name          = var.ecs_config.container_name
  container_port          = module.task_definition.container_ports[var.ecs_config.container_name]

  vpc_id                = var.vpc_id
  private_subnet_ids    = var.private_subnet_ids
  public_subnet_ids     = var.public_subnet_ids
  alb_security_group_id = local.alb_security_group_id

  # Dev: assign_public_ip = true  → ECS tasks in public subnets, direct internet access.
  # Prod: assign_public_ip = false → ECS tasks in private subnets, outbound via NAT Gateway.
  assign_public_ip = var.assign_public_ip

  desired_count              = var.desired_capacity
  target_group_arn           = local.target_group_arn
  enable_auto_scaling        = true
  auto_scaling_min_capacity  = var.min_capacity
  auto_scaling_max_capacity  = var.max_capacity
  cpu_target_value           = var.cpu_threshold
  memory_target_value        = var.memory_threshold
  enable_cloudwatch_alarms   = var.enable_cloudwatch_alarms
  alarm_actions_enabled      = var.alarm_actions_enabled
  task_count_alarm_threshold = var.task_count_alarm_threshold
  sns_topic_alarm_arn        = var.sns_topic_alarm_arn
}

# ── CloudWatch Alarm: ALB target(s) unhealthy ─────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count               = (var.create_alb && var.enable_cloudwatch_alarms) ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "heatmap-japan-netty-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "One or more heatmap-japan-netty targets behind heatmap-netty-alb are failing health checks"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.alb[0].alb_arn_suffix
    TargetGroup  = module.alb[0].target_group_arn_suffix
  }

  tags = var.common_tags
}

# Netty logs to /aws/ecs/task/heatmap-japan-netty (see task_definition module above).
resource "aws_cloudwatch_log_metric_filter" "redis_exception" {
  count          = var.enable_cloudwatch_alarms ? 1 : 0
  name           = "heatmap-japan-netty-RedisException"
  log_group_name = module.task_definition.log_group_name
  pattern        = "\"org.redisson.client.\""

  metric_transformation {
    name          = "RedisExceptionCount"
    namespace     = "Heatmap/heatmap-japan-netty"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "valkey_write_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "heatmap-japan-netty-valkey-write-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.redis_exception[0].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.redis_exception[0].metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "RedisException logged by heatmap-japan-netty - Valkey read/write is failing"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  tags = var.common_tags
}

# ── Websocket exception rate ─────────
resource "aws_cloudwatch_log_metric_filter" "websocket_exception" {
  count          = var.enable_cloudwatch_alarms ? 1 : 0
  name           = "heatmap-japan-netty-WebsocketException"
  log_group_name = module.task_definition.log_group_name
  pattern        = "\"Error websocket\" \"Exception\" -\"WebSocketServerHandshakeException\""

  metric_transformation {
    name          = "WebsocketExceptionCount"
    namespace     = "Heatmap/heatmap-japan-netty"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "websocket_exception_rate_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  actions_enabled     = var.alarm_actions_enabled
  alarm_name          = "HeatmapNettyECSWebsocketExceptionRateHigh"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = aws_cloudwatch_log_metric_filter.websocket_exception[0].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.websocket_exception[0].metric_transformation[0].namespace
  period              = 180
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Websocket exceptions >=100/min detected from heatmap-japan-netty ECS logs (/aws/ecs/task/heatmap-japan-netty)"
  alarm_actions       = [var.sns_topic_alarm_arn]
  treat_missing_data  = "notBreaching"

  tags = var.common_tags
}