# ALB Module Outputs

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer for Route53"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the ECS target group"
  value       = aws_lb_target_group.ecs.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the ECS target group (for CloudWatch TargetGroup dimension)"
  value       = aws_lb_target_group.ecs.arn_suffix
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch LoadBalancer dimension)"
  value       = aws_lb.main.arn_suffix
}
