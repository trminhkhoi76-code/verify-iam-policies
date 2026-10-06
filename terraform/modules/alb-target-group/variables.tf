variable "name" {
  description = "Name of the target group"
  type        = string
}

variable "port" {
  description = "Port on which targets receive traffic"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID where the target group is created"
  type        = string
}

variable "health_check_path" {
  description = "Destination for the health check request"
  type        = string
  default     = "/"
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required before considering target healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering target unhealthy"
  type        = number
  default     = 3
}

variable "health_check_timeout" {
  description = "Amount of time (in seconds) during which no response means a failed health check"
  type        = number
  default     = 10
}

variable "health_check_interval" {
  description = "Approximate amount of time (in seconds) between health checks"
  type        = number
  default     = 30
}

variable "health_check_matcher" {
  description = "HTTP codes to use when checking for a successful response from a target"
  type        = string
  default     = "200"
}

variable "deregistration_delay" {
  description = "Amount time for Elastic Load Balancing to wait before deregistering a target"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

