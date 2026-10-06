# ECS Task Definition Module
# Creates reusable task definitions for ECS services

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Simple locals to add defaults for missing fields
locals {
  processed_containers = [
    for container in var.container_definitions : merge({
      # Default port mapping
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      
      # Default log configuration  
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/task/${var.task_family}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = container.name
          "awslogs-multiline-pattern" = "^(\\s+at\\s|Caused by:|\\s+\\.\\.\\.\\s+\\d+\\smore|\\t)"
        }
      }
      
      # Default health check
      healthCheck = {
        command     = ["CMD-SHELL", var.health_check_command]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Fargate's hard maximum grace period before SIGKILL; gives the app time to
      # drain in-flight work/connections (e.g. Netty WebSocket clients) on stop.
      stopTimeout = 120
    }, container)  # User values will override defaults
  ]
}

# CloudWatch Log Group for Task Logs
resource "aws_cloudwatch_log_group" "task_logs" {
  name              = "/aws/ecs/task/${var.task_family}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name      = "${var.task_family}-logs"
    TaskFamily = var.task_family
    Type      = "TaskLogs"
  })
}

# IAM Task Execution Role
resource "aws_iam_role" "task_execution_role" {
  name = "${var.task_family}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.task_family}-execution-role"
    TaskFamily = var.task_family
    Type       = "ExecutionRole"
  })
}

# Attach AWS managed policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECR access policy (always enabled)
resource "aws_iam_policy" "task_execution_ecr" {
  name        = "${var.task_family}-execution-ecr-policy"
  description = "Allow ECR access for ${var.task_family} task execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"  # GetAuthorizationToken requires * resource
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer", 
          "ecr:BatchGetImage"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:*:repository/${var.task_family}*"
        ]
      }
    ]
  })

  tags = var.common_tags
}

# Attach ECR policy to execution role
resource "aws_iam_role_policy_attachment" "task_execution_ecr" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_ecr.arn
}

# IAM Task Role (for application permissions)
resource "aws_iam_role" "task_role" {
  name = "${var.task_family}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.task_family}-task-role"
    TaskFamily = var.task_family
    Type       = "TaskRole"
  })
}

# IAM Policy for Task Role - Parameter Store Access
resource "aws_iam_policy" "task_parameter_store" {
  name        = "${var.task_family}-parameter-store-policy"
  description = "Allow access to Parameter Store for ${var.task_family}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/heatmap/${var.parameter_store_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:*:key/*"
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach Parameter Store Policy to Task Role
resource "aws_iam_role_policy_attachment" "task_parameter_store" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_parameter_store.arn
}

# IAM Policy for ECS Exec (SSM Session Manager)
resource "aws_iam_policy" "task_ecs_exec" {
  name        = "${var.task_family}-ecs-exec-policy"
  description = "Allow ECS Exec access for ${var.task_family}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/containerinsights/*"
      }
    ]
  })

  tags = var.common_tags
}

# Attach ECS Exec Policy to Task Role
resource "aws_iam_role_policy_attachment" "task_ecs_exec" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_ecs_exec.arn
}

# IAM Policy for S3 access (optional, only created when s3_bucket_name is provided)
resource "aws_iam_policy" "task_s3_access" {
  count       = (var.s3_bucket_name != "" || var.s3_rds_bucket_name != "") ? 1 : 0
  name        = "${var.task_family}-s3-access-policy"
  description = "Allow S3 GetObject and PutObject access for ${var.task_family}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_rds_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_rds_bucket_name}"
        ]
      }
    ]
  })

  tags = var.common_tags
}

# Attach S3 Policy to Task Role
resource "aws_iam_role_policy_attachment" "task_s3_access" {
  count      = (var.s3_bucket_name != "" || var.s3_rds_bucket_name != "") ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_s3_access[0].arn
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = toset(var.additional_policy_arns)
  
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  execution_role_arn      = aws_iam_role.task_execution_role.arn
  task_role_arn           = aws_iam_role.task_role.arn

  # Resource requirements (required for Fargate)
  cpu    = tostring(var.task_cpu)
  memory = tostring(var.task_memory)

  # Container definitions
  container_definitions = jsonencode(local.processed_containers)

  tags = merge(var.common_tags, {
    Name       = var.task_family
    TaskFamily = var.task_family
  })

  # Skip deregistering task definition on destroy
  # Avoids needing ecs:DeregisterTaskDefinition permission
  skip_destroy = true

  lifecycle {
    create_before_destroy = true
  }
}