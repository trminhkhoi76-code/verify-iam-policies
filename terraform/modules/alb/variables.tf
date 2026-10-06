# ALB Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB and target group will be created"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules for ALB security group"
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), [])
    security_groups  = optional(list(string), [])
  }))
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "http_redirect_to_https" {
  description = "When certificate_arn is set: true → HTTP:80 returns a 301 to HTTPS; false → HTTP:80 forwards to the target group (needed for plain-HTTP / ws:// clients). Ignored when certificate_arn is empty (port 80 always forwards)."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "target_port" {
  description = "Port on which targets receive traffic"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path for health check requests. Use /actuator/health for Spring Boot Actuator, /healthz for generic apps."
  type        = string
  default     = "/actuator/health"
}

variable "idle_timeout" {
  description = "Time in seconds an idle connection is allowed to remain open before the ALB closes it"
  type        = number
  default     = 60
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "access_logs_enabled" {
  description = "Whether to enable access logs for the ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 key prefix for ALB access logs"
  type        = string
  default     = ""
}
