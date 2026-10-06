# ECS Cluster Module Variables

variable "cluster_name" {
  description = "Cluster name"
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

# Log configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days for Container Insights"
  type        = number
  default     = 14
}

variable "exec_log_retention_days" {
  description = "CloudWatch log retention in days for ECS Exec logs"
  type        = number
  default     = 1
}