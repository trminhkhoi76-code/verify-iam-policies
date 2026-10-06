# heatmap-popup-console – ALB (optional) + ECS Task Definition + ECS Service


# ── Locals to unify references across both modes ─────────────────────────
locals {
  target_group_arn      = var.create_alb ? module.alb[0].target_group_arn : var.external_target_group_arn
  alb_security_group_id = var.create_alb ? module.alb[0].alb_security_group_id : var.external_alb_security_group_id
}

# ── ALB – only created when create_alb = true (prod) ────────────────────
module "alb" {
  source = "../alb"
  count  = var.create_alb ? 1 : 0

  name_prefix       = "heatmap-popup"
  vpc_id            = var.vpc_id
  public_subnet_ids = var.public_subnet_ids
  ingress_rules     = var.alb_ingress_rules
  common_tags       = var.common_tags
  target_port       = var.ecs_config.container_port
  health_check_path = var.health_check_path
  certificate_arn   = var.certificate_arn

  enable_deletion_protection = false
}

module "task_definition" {
  source = "../ecs-task-definition"

  task_family        = "heatmap-popup-console"
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
      { name = "JAVA_OPTS", value = var.java_opts },
      { name = "TZ",        value = "Asia/Tokyo"  }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"             = "/aws/ecs/task/heatmap-popup-console"
        "awslogs-region"            = var.aws_region
        "awslogs-stream-prefix"     = var.ecs_config.container_name
        "awslogs-multiline-pattern" = "^\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\s+(INFO|ERROR|WARN|DEBUG|TRACE)"
      }
    }

    portMappings = [{
      containerPort = var.ecs_config.container_port
      protocol      = "tcp"
    }]

    # Health check path must match the ALB target group health_check_path.
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.ecs_config.container_port}${var.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
  }]

  parameter_store_prefix = "heatmapjapan-console"
  s3_bucket_name         = var.s3_bucket_name
  s3_rds_bucket_name     = var.s3_rds_bucket_name
  additional_policy_arns = []
}

module "ecs_service" {
  source = "../ecs-service"

  service_name  = "heatmap-popup-console"
  common_tags   = var.common_tags
  aws_region    = var.aws_region
  cluster_id    = var.cluster_id
  cluster_name  = var.cluster_name

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

  desired_count             = var.desired_capacity
  target_group_arn          = local.target_group_arn
  enable_auto_scaling       = true
  auto_scaling_min_capacity = var.min_capacity
  auto_scaling_max_capacity = var.max_capacity
  cpu_target_value          = var.cpu_threshold
  memory_target_value       = var.memory_threshold
  task_count_alarm_threshold = var.task_count_alarm_threshold
  sns_topic_alarm_arn        = var.sns_topic_alarm_arn
}

# ── Security group rules for existing infrastructure ──────────────────────

# Allow ECS tasks → RDS (port 3306)
resource "aws_security_group_rule" "rds_from_ecs" {
  count                    = var.existing_rds_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.ecs_service.ecs_security_group_id
  security_group_id        = var.existing_rds_security_group_id
  description              = "MySQL/Aurora from heatmap-japan ECS tasks"
}

# Allow ECS tasks → Valkey (port 6379)
resource "aws_security_group_rule" "valkey_from_ecs" {
  count                    = var.existing_valkey_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = var.valkey_port_range
  to_port                  = var.valkey_port_range
  protocol                 = "tcp"
  source_security_group_id = module.ecs_service.ecs_security_group_id
  security_group_id        = var.existing_valkey_security_group_id
  description              = "Valkey from heatmap-popup-console ECS tasks"
}
