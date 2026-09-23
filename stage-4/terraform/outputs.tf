# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 4 - ElastiCache Redis In-Memory Caching)
# ==============================================================================

output "redis_endpoint" {
  description = "The primary endpoint hostname of the Amazon ElastiCache Redis node"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "The port of the Amazon ElastiCache Redis cluster"
  value       = module.elasticache.redis_port
}

output "redis_cluster_id" {
  description = "The cluster identifier of the Amazon ElastiCache Redis cluster"
  value       = module.elasticache.cluster_id
}

output "elasticache_security_group_id" {
  description = "The ID of the Amazon ElastiCache Redis Security Group"
  value       = aws_security_group.elasticache.id
}

output "cache_subnet_group_name" {
  description = "The name of the ElastiCache subnet group"
  value       = module.elasticache.subnet_group_name
}

output "alb_dns_name" {
  description = "The public DNS hostname of the Application Load Balancer from Stage 3"
  value       = local.alb_dns_name
}

output "application_url" {
  description = "The public web entry point for ShopSphere through the Application Load Balancer"
  value       = local.alb_dns_name != "" ? "http://${local.alb_dns_name}" : ""
}

output "cache_verification_command" {
  description = "Run twice to observe CACHE MISS on first query, then instant CACHE HIT on subsequent query"
  value       = local.alb_dns_name != "" ? "curl -i -s http://${local.alb_dns_name}/api/products | grep -E 'X-Cache|latencyMs|source'" : ""
}
