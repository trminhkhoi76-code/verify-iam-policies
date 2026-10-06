variable "project_name" {
  description = "Project name used as prefix for resources"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda timeout (seconds)"
  type        = number
}

variable "lambda_memory_size" {
  description = "Lambda memory size (MB)"
  type        = number
}

variable "lambda_architectures" {
  description = "Lambda architectures"
  type        = list(string)
}

variable "lambda_environment_variables" {
  description = "Additional environment variables for the Lambda function"
  type        = map(string)
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda function"
  type        = string
}

variable "lambda_log_retention_in_days" {
  description = "CloudWatch log retention for lambda"
  type        = number
}

variable "lambda_alias" {
  description = "Lambda alias name for the schedule target (e.g., 'live', 'prod')"
  type        = string
  default     = null
}

variable "vpc_config" {
  description = "VPC config for lambda"
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
}

variable "create_security_group" {
  description = "Whether to create a security group for lambda when vpc_config is set"
  type        = bool
  default     = false
}

variable "rds_security_group_id" {
  description = "RDS Security Group ID to allow Lambda access. If provided, an ingress rule is created."
  type        = string
  default     = null
}

variable "smg_end_point_sg_id" {
  description = "Secrets Manager VPC endpoint security group ID to allow Lambda access on 443."
  type        = string
  default     = null
}

variable "schedule_name" {
  description = "Logical schedule name (will be prefixed by project_name)"
  type        = string
}

variable "schedule_description" {
  description = "Schedule description"
  type        = string
}

variable "schedule_expression" {
  description = "Schedule expression"
  type        = string
}

variable "schedule_expression_timezone" {
  description = "Schedule timezone"
  type        = string
}

variable "schedule_enabled" {
  description = "Enable schedule"
  type        = bool
}

variable "schedule_input" {
  description = "Optional input payload for the target"
  type        = any
}

variable "scheduler_role_arn" {
  description = "IAM role ARN for EventBridge Scheduler"
  type        = string
}

variable "schedule_retry_policy" {
  description = "Retry policy for EventBridge Scheduler"
  type = object({
    maximum_event_age_in_seconds = number
    maximum_retry_attempts       = number
  })
}
