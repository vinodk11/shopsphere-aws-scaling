# ==============================================================================
# ElastiCache Module Variables - Stage 4
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage4, dev, prod)"
  type        = string
}

variable "cache_subnet_ids" {
  description = "List of private subnet IDs for ElastiCache Subnet Group across at least 2 AZs"
  type        = list(string)
}

variable "elasticache_security_group_id" {
  description = "Security group ID allowing inbound port 6379 from EC2"
  type        = string
}

variable "cache_node_type" {
  description = "The compute and memory capacity of the nodes (e.g. cache.t3.micro, cache.t4g.micro)"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Port on which Redis accepts connections"
  type        = number
  default     = 6379
}

variable "tags" {
  description = "Common tags applied to all ElastiCache resources"
  type        = map(string)
  default     = {}
}
