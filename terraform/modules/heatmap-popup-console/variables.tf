# Heatmap Popup Console Module Variables

# ── ALB Mode ──────────────────────────────────────────────────────────────
# create_alb = true  (default) → create a brand-new ALB + TG (prod)
# create_alb = false            → no ALB/TG, ECS runs standalone (dev)
variable "create_alb" {
  description = "Whether to create a new ALB and target group. Set to false for standalone ECS (no load balancer)."
  type        = bool
  default     = true
}

variable "external_target_group_arn" {
  description = "ARN of an externally-managed target group (e.g. created via Console). Used when create_alb = false but ECS still needs a load_balancer block."
  type        = string
  default     = ""
}

variable "external_alb_security_group_id" {
  description = "SG ID of the shared/external ALB. Required when create_alb = false so ECS tasks allow inbound health-check probes from the ALB."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Network variables
variable "vpc_id" {
  description = "VPC ID for security groups and target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Subnet IDs where ECS tasks run. Use public subnets (dev) or private subnets (prod)."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks. true for dev (public subnets, no NAT), false for prod (private subnets with NAT Gateway)."
  type        = bool
}

# SSL Certificate (only used when create_alb = true)
variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "alb_ingress_rules" {
  description = "List of ingress rules for ALB security group (only used when create_alb = true)"
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), [])
    security_groups  = optional(list(string), [])
  }))
  default = []
}

# Existing Infrastructure Security Groups
variable "existing_rds_security_group_id" {
  description = "ID of existing RDS security group to allow ECS access"
  type        = string
}

variable "existing_valkey_security_group_id" {
  description = "ID of existing Valkey security group to allow ECS access"
  type        = string
  default     = ""
}

variable "sns_topic_alarm_arn" {
  description = "SNS topic ARN for ECS CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# S3 Configuration
variable "s3_bucket_name" {
  description = "S3 bucket name for popup image upload/download"
  type        = string
  default     = ""
}


# ECS Configuration
variable "ecs_config" {
  description = "ECS configuration settings"
  type = object({
    container_name     = string
    container_port     = number
    cpu                = number
    memory             = number
    log_retention_days = number
  })
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL (managed externally to avoid duplication)"
  type        = string
}

variable "java_opts" {
  description = "JVM options for Java application"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path for ALB target group and container health checks. Must match an endpoint the app actually serves."
  type        = string
}

# ECS Cluster Configuration (from shared cluster)
variable "cluster_id" {
  description = "ECS Cluster ID (from shared cluster)"
  type        = string
}

variable "cluster_name" {
  description = "ECS Cluster name (from shared cluster)"
  type        = string
}

# Scaling configuration

variable "min_capacity" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of instances"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "cpu_threshold" {
  description = "CPU threshold for scaling up"
  type        = number
}

variable "memory_threshold" {
  description = "Memory threshold for scaling up"
  type        = number
  default     = 70
}

variable "task_count_alarm_threshold" {
  description = "Threshold for task count alarm - alert when running tasks exceed this number"
  type        = number
}


variable "s3_rds_bucket_name" {
  description = "S3 bucket RDS Truststore name for download rds truststore"
  type        = string
  default     = ""
}


variable "valkey_port_range" {
  description = "Starting port number for Valkey (Redis) security group rule"
  type        = number
  default     = 6379
}