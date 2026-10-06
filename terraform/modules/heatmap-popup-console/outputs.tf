# Heatmap Popup Console ECS Module Outputs

# ALB Outputs - Only available when create_alb = true (prod)
output "alb_dns_name" {
  description = "ALB DNS name for Route53 or direct access"
  value       = var.create_alb ? module.alb[0].alb_dns_name : null
}

output "alb_zone_id" {
  description = "ALB Zone ID for Route53 alias record"
  value       = var.create_alb ? module.alb[0].alb_zone_id : null
}

# Target Group Output
output "target_group_arn" {
  description = "ARN of the target group used by ECS service"
  value       = local.target_group_arn
}

# ECS Service Output
output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_service.service_name
}

output "ecs_security_group_id" {
  description = "ECS Security Group ID"
  value       = module.ecs_service.ecs_security_group_id
}

output "assign_public_ip" {
  description = "Whether ECS tasks are assigned public IPs (true = public subnets / dev, false = private subnets / prod)"
  value       = var.assign_public_ip
}
