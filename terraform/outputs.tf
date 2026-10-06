output "valkey_endpoint" {
  description = "Valkey cluster endpoint"
  value       = module.valkey.endpoint
}

output "valkey_port" {
  description = "Valkey port"  
  value       = module.valkey.port
}

output "valkey_security_group_id" {
  description = "Valkey security group ID"
  value       = module.valkey.security_group_id
}

# ================================================================
# Valkey Data Setting Outputs
# ================================================================
output "valkey_data_setting_id" {
  value = module.valkey_data_setting.id
  description = "Valkey Data Setting replication group ID"
}

output "valkey_data_setting_endpoint" {
  description = "Valkey Data Setting cluster endpoint"
  value       = module.valkey_data_setting.endpoint
}

output "valkey_data_setting_primary_endpoint" {
  description = "Valkey Data Setting primary endpoint (READ/WRITE)"
  value       = module.valkey_data_setting.primary_endpoint
}

output "valkey_data_setting_reader_endpoint" {
  description = "Valkey Data Setting reader endpoint (READ-ONLY replicas)"
  value       = module.valkey_data_setting.reader_endpoint
}

output "valkey_data_setting_member_clusters" {
  description = "Valkey Data Setting list of all cluster members"
  value       = module.valkey_data_setting.member_clusters
}

output "valkey_data_setting_port" {
  description = "Valkey Data Setting port"
  value       = module.valkey_data_setting.port
}

output "valkey_data_setting_security_group_id" {
  description = "Valkey Data Setting security group ID"
  value       = module.valkey_data_setting.security_group_id
}

# ================================================================
# ECR Outputs
# ================================================================
output "ecr_repositories" {
  description = "Map of ECR repositories (key → { url, arn, name })"
  value = {
    for k, mod in module.ecr : k => {
      repository_url  = mod.repository_url
      repository_arn  = mod.repository_arn
      repository_name = mod.repository_name
    }
  }
}

# ================================================================
# ECS Cluster Outputs
# ================================================================
output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.ecs_cluster.cluster_name
}

# ================================================================
# ALB + ECS Service Outputs (heatmap-popup-netty)
# ================================================================
output "netty_alb_dns_name" {
  description = "ALB DNS name for heatmap-popup-netty"
  value       = length(module.heatmap_popup_netty) > 0 ? module.heatmap_popup_netty[0].alb_dns_name : null
}

output "netty_alb_zone_id" {
  description = "ALB Zone ID for heatmap-popup-netty"
  value       = length(module.heatmap_popup_netty) > 0 ? module.heatmap_popup_netty[0].alb_zone_id : null
}

output "netty_ecs_service_name" {
  description = "ECS Service name for heatmap-popup-netty"
  value       = length(module.heatmap_popup_netty) > 0 ? module.heatmap_popup_netty[0].ecs_service_name : null
}

# ================================================================
# ALB + ECS Service Outputs (heatmap-popup-console)
# ================================================================
output "alb_dns_name" {
  description = "ALB DNS name for heatmap-popup-console"
  value       = length(module.heatmap_popup_console) > 0 ? module.heatmap_popup_console[0].alb_dns_name : null
}

output "alb_zone_id" {
  description = "ALB Zone ID for heatmap-popup-console"
  value       = length(module.heatmap_popup_console) > 0 ? module.heatmap_popup_console[0].alb_zone_id : null
}

output "ecs_service_name" {
  description = "ECS Service name for heatmap-popup-console"
  value       = length(module.heatmap_popup_console) > 0 ? module.heatmap_popup_console[0].ecs_service_name : null
}

# ================================================================
# ALB + ECS Service Outputs (heatmap-japan-netty)
# ================================================================
output "heatmap_japan_netty_alb_dns_name" {
  description = "ALB DNS name for heatmap-japan-netty (heatmap-netty-alb; null in dev)"
  value       = length(module.heatmap_japan_netty) > 0 ? module.heatmap_japan_netty[0].alb_dns_name : null
}

output "heatmap_japan_netty_alb_zone_id" {
  description = "ALB Zone ID for heatmap-japan-netty (for Route53 alias record; null in dev)"
  value       = length(module.heatmap_japan_netty) > 0 ? module.heatmap_japan_netty[0].alb_zone_id : null
}

output "heatmap_japan_netty_ecs_service_name" {
  description = "ECS Service name for heatmap-japan-netty"
  value       = length(module.heatmap_japan_netty) > 0 ? module.heatmap_japan_netty[0].ecs_service_name : null
}

output "heatmap_japan_netty_ecs_security_group_id" {
  description = "ECS Security Group ID for heatmap-japan-netty tasks"
  value       = length(module.heatmap_japan_netty) > 0 ? module.heatmap_japan_netty[0].ecs_security_group_id : null
}
