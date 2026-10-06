# ECS Task Definition Module Outputs

output "task_definition_arn" {
  description = "ARN of the ECS task definition (required for ECS service)"
  value       = aws_ecs_task_definition.main.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group name for task logs (/aws/ecs/task/<task_family>)"
  value       = aws_cloudwatch_log_group.task_logs.name
}

output "container_names" {
  description = "List of container names (for load balancer configuration)"
  value       = [for container in var.container_definitions : container.name]
}

output "container_ports" {
  description = "Map of container names to their ports (for load balancer configuration)"
  value = {
    for container in var.container_definitions : container.name => 
    try(
      length(coalesce(container.portMappings, [])) > 0 ? container.portMappings[0].containerPort : 8080,
      8080
    )
  }
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.task_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.task_role.arn
}