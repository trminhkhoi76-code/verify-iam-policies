# ECS Cluster Module - Shared Cluster for Multiple Services

# ECS Cluster with Container Insights
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}

# ECS Cluster Capacity Provider (Fargate)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for Container Insights (Cluster level)
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/ecs/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-container-insights"
    Type = "ContainerInsights"
  })
}

# CloudWatch Log Group for ECS Exec (Cluster level)
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/containerinsights/${var.cluster_name}/exec"
  retention_in_days = var.exec_log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-exec-logs"
    Type = "ExecLogs"
  })
}



