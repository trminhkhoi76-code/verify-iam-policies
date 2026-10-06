variable "cluster_name" {
  description = "Name of the Valkey cluster"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "ingress_rules" {
  description = "List of ingress rules with security group IDs and descriptions"
  type = list(object({
    from_port                = optional(number, null)
    to_port                  = optional(number, null)
    protocol                 = optional(string, "tcp")
    security_group_id        = optional(string, null)
    cidr_blocks              = optional(list(string), null)
    description              = string
  }))
  default = []
}

variable "node_type" {
  description = "The instance class for Valkey nodes"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

variable "port" {
  description = "Port for Valkey"
  type        = number
  default     = 6379
}

variable "engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.1"
}

variable "parameter_group_parameters" {
  description = "List of parameter name/value pairs for the custom parameter group"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "create_parameter_group" {
  description = "Whether to create a custom parameter group (even without custom parameters)"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Specifies whether to enable Multi-AZ Support"
  type        = bool
  default     = true
}

variable "at_rest_encryption_enabled" {
  description = "Whether to enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Whether to enable encryption in transit"
  type        = bool
  default     = true
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Time window for snapshots"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_cloudwatch_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm"
  type        = number
  default     = 70
}

variable "memory_alarm_threshold" {
  description = "Memory usage threshold for alarm (in bytes)"
  type        = number
  default     = 500 * 1024 * 1024 # 500 MB
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
