# Heatmap Japan Netty Module Variables

# ── Container image ───────────────────────────────────────────────────────────
variable "ecr_repository_url" {
  description = "ECR repository URL for heatmap-japan-netty (managed via root ecr_repositories for_each)"
  type        = string
}

# ── ALB Mode ──────────────────────────────────────────────────────────────────
variable "create_alb" {
  description = "Whether to create a new ALB and target group. Set to false for dev (shared ALB, external TG)."
  type        = bool
  default     = true
}

variable "external_target_group_arn" {
  description = "ARN of an externally-managed target group. Used when create_alb = false but ECS still needs a load_balancer block."
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

# ── Network ───────────────────────────────────────────────────────────────────
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

# ── ALB configuration (only used when create_alb = true) ─────────────────────
variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty for HTTP-only ALB (dev)."
  type        = string
  default     = ""
}

variable "http_redirect_to_https" {
  description = "When certificate_arn is set: true → HTTP:80 returns a 301 to HTTPS; false → HTTP:80 forwards to the target group. Kept false so ws:// clients on port 80 still reach Netty."
  type        = bool
  default     = false
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

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for ECS service (memory, task count, etc.)"
  type        = bool
  default     = true
}

variable "alarm_actions_enabled" {
  description = "Whether alarms notify (SNS) when triggered. false keeps alarms visible/testable in the CloudWatch console without sending notifications."
  type        = bool
  default     = true
}

variable "sns_topic_alarm_arn" {
  description = "SNS topic ARN for ECS CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
variable "cluster_id" {
  description = "ECS Cluster ID (from shared cluster)"
  type        = string
}

variable "cluster_name" {
  description = "ECS Cluster name (from shared cluster)"
  type        = string
}

# ── Container / Task ─────────────────────────────────────────────────────────
variable "ecs_config" {
  description = "ECS task and container configuration"
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
  default     = "latest"
}

variable "java_opts" {
  description = "JVM options passed as JAVA_OPTS environment variable"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path for ALB target group and container health checks."
  type        = string
  default     = "/"
}

# ── Auto Scaling ─────────────────────────────────────────────────────────────
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "cpu_threshold" {
  description = "CPU utilization % target for auto-scaling"
  type        = number
}

variable "memory_threshold" {
  description = "Memory utilization % target for auto-scaling"
  type        = number
  default     = 70
}

variable "task_count_alarm_threshold" {
  description = "Alert when running task count exceeds this number (detects unexpected over-scaling)"
  type        = number
}
