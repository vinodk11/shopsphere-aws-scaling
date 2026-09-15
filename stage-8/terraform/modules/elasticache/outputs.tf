# ==============================================================================
# ElastiCache Module Outputs - Stage 4
# ==============================================================================

output "cluster_id" {
  description = "The ElastiCache cluster identifier"
  value       = aws_elasticache_cluster.this.cluster_id
}

output "redis_endpoint" {
  description = "The DNS endpoint address of the Redis cache node"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "redis_port" {
  description = "The port of the Redis cluster"
  value       = aws_elasticache_cluster.this.port
}

output "subnet_group_name" {
  description = "The name of the ElastiCache subnet group"
  value       = aws_elasticache_subnet_group.this.name
}
