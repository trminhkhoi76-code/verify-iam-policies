# ECS Service Module Variables

variable "service_name" {
  description = "Name for the ECS service (e.g., 'heatmap-popup-console')"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Cluster Configuration
variable "cluster_id" {
  description = "ECS Cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS Cluster name"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS Task Execution Role ARN (from shared cluster)"
  type        = string
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID for security group creation"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnet IDs for ECS tasks. Use private subnets (with NAT/VPC endpoints) in production;"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ECS tasks when assign_public_ip is true."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks. Set to false when using private subnets with NAT Gateway, true when tasks need direct internet access."
  type        = bool
  default     = false
}

variable "alb_security_group_id" {
  description = "ALB security group ID to allow traffic from. Leave empty if no ALB is used."
  type        = string
  default     = ""
}

# Task Definition Configuration
variable "task_definition_arn" {
  description = "ARN of the ECS Task Definition to use for this service"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group for load balancer integration"
  type        = string
  default     = ""
}

# Container Configuration (for Load Balancer)
variable "container_name" {
  description = "Name of the container to route traffic to (must match container in task definition)"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container (must match port in task definition)"
  type        = number
}



variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}



# Service Discovery
variable "service_discovery_arn" {
  description = "ARN of the service discovery service"
  type        = string
  default     = ""
}

# Auto Scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "auto_scaling_min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "auto_scaling_max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target value for CPU utilization auto scaling policy"
  type        = number
  default     = 70.0
}

variable "memory_target_value" {
  description = "Target value for Memory utilization auto scaling policy"
  type        = number
  default     = 80.0
}

# Monitoring
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_actions_enabled" {
  description = "Whether alarms notify (SNS) when triggered. false keeps alarms visible/testable in the CloudWatch console without sending notifications."
  type        = bool
  default     = true
}

variable "sns_topic_alarm_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
  default     = ""
}

variable "task_count_alarm_threshold" {
  description = "Threshold for task count alarm (alert when running tasks exceed this number)"
  type        = number
  default     = 5
}

# IAM
variable "task_role_arn" {
  description = "ARN of the task role (optional, will use execution role if not provided)"
  type        = string
  default     = ""
}

# Execute Command
variable "enable_execute_command" {
  description = "Enable execute command for debugging"
  type        = bool
  default     = true
}

# Health Check
variable "health_check_grace_period_seconds" {
  description = "Time period (in seconds) during which ECS ignores health check failures. Useful for apps with slow startup"
  type        = number
  default     = 180
}

# Log configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}