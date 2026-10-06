# ECS Task Definition Module Variables

variable "task_family" {
  description = "Task definition family name (e.g., 'heatmap-popup-console')"
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

# Task Resource Configuration
variable "task_cpu" {
  description = "CPU units for the task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 512
}

# Container Definitions
variable "container_definitions" {
  description = "List of container definitions. Only name and image are required, rest will use defaults from variables."
  type = list(object({
    name         = string
    image        = string
    cpu          = optional(number)
    memory       = optional(number)
    essential    = optional(bool)
    portMappings = optional(list(object({
      containerPort = number
      protocol      = optional(string)
    })))
    environment = optional(list(object({
      name  = string
      value = string
    })))
    secrets = optional(list(object({
      name      = string
      valueFrom = string
    })))
    logConfiguration = optional(object({
      logDriver = string
      options   = map(string)
    }))
    healthCheck = optional(object({
      command     = list(string)
      interval    = optional(number)
      timeout     = optional(number)
      retries     = optional(number)
      startPeriod = optional(number)
    }))
    ulimits = optional(list(object({
      name      = string
      softLimit = number
      hardLimit = number
    })))
  }))
}

variable "container_port" {
  description = "Default port for containers if no port mappings specified"
  type        = number
  default     = 8080
}

variable "health_check_command" {
  description = "Default health check command for containers. Uses generic HTTP check on port 8080. Override in container_definitions for custom health checks."
  type        = string
  default     = "wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1"
}

# Log Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# IAM Configuration
variable "parameter_store_prefix" {
  description = "SSM Parameter Store path prefix (e.g. 'heatmapjapan-console'). Leading/trailing slashes are stripped when building the IAM resource ARN."
  type        = string
  default     = ""

  validation {
    condition     = var.parameter_store_prefix == "" || can(regex("^[a-zA-Z0-9/_-]+$", var.parameter_store_prefix))
    error_message = "parameter_store_prefix may only contain alphanumeric characters, hyphens, underscores, and forward slashes."
  }
}

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the task role"
  type        = list(string)
  default     = []
}

variable "s3_bucket_name" {
  description = "S3 bucket name for object access (GetObject, PutObject). Leave empty to skip S3 policy creation."
  type        = string
  default     = ""
}


variable "s3_rds_bucket_name" {
  description = "S3 bucket RDS Truststore name for object access (GetObject). Leave empty to skip S3 policy creation."
  type        = string
  default     = ""
}
