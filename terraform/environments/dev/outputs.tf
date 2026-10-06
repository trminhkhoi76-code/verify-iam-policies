# Exercises elasticache:DescribeReplicationGroups through a data source
data "aws_elasticache_replication_group" "valkey" {
  replication_group_id = module.valkey.id
}

output "valkey_primary_endpoint" {
  description = "Valkey primary endpoint (READ/WRITE)"
  value       = data.aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "valkey_reader_endpoint" {
  description = "Valkey reader endpoint (READ-ONLY replicas)"
  value       = data.aws_elasticache_replication_group.valkey.reader_endpoint_address
}

output "valkey_port" {
  description = "Valkey port"
  value       = data.aws_elasticache_replication_group.valkey.port
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "state_machine_arn" {
  value = module.step_function.state_machine_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecs_service_name" {
  value = module.ecs_service.service_name
}

output "route53_health_check_heatmap_domain" {
  description = "Route 53 health check ID for heatmap domain (dev.ntjp.mieru-ca.com) — for status checks"
  value       = aws_route53_health_check.heatmap_japan_netty_domain.id
}
