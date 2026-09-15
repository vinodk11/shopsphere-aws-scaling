# ==============================================================================
# ElastiCache Module - Stage 4 Amazon ElastiCache Redis
# Provisions Multi-AZ Subnet Group, Custom Parameter Group, and Redis Cluster
# ==============================================================================

# 1. ElastiCache Subnet Group across private cache subnets
resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-cache-subnet-group"
  description = "ShopSphere Redis cache subnet group across multiple private AZs"
  subnet_ids  = var.cache_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cache-subnet-group"
      Tier = "Private-Cache"
    }
  )
}

# 2. ElastiCache Parameter Group (Redis 7)
resource "aws_elasticache_parameter_group" "this" {
  name        = "${var.project_name}-${var.environment}-redis7-params"
  family      = "redis7"
  description = "ShopSphere custom parameter group for Redis 7 LRU eviction"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-params"
      Tier = "Private-Cache"
    }
  )
}

# 3. Amazon ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  node_type            = var.cache_node_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.this.name
  engine_version       = var.redis_engine_version
  port                 = var.redis_port
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.elasticache_security_group_id]
  apply_immediately    = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-cluster"
      Tier = "Private-Cache"
    }
  )
}
