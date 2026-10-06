# ECS Service Module Outputs

output "ecs_security_group_id" {
  description = "ECS Security Group ID"
  value       = aws_security_group.ecs.id
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_cluster" {
  description = "Cluster name where service is running"
  value       = aws_ecs_service.main.cluster
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for the service"
  value       = aws_cloudwatch_log_group.ecs_service.name
}