# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 4 - ElastiCache Redis + RDS + ALB)
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets hosting the ALB and EC2 ASG instances"
  value       = module.vpc.public_subnet_ids
}

output "private_db_subnet_ids" {
  description = "List of IDs of private subnets hosting the Amazon RDS database"
  value       = module.vpc.private_db_subnet_ids
}

output "private_cache_subnet_ids" {
  description = "List of IDs of private subnets hosting the Amazon ElastiCache Redis cluster"
  value       = module.vpc.private_cache_subnet_ids
}

# ------------------------------------------------------------------------------
# Security Group Outputs
# ------------------------------------------------------------------------------

output "alb_security_group_id" {
  description = "The ID of the Application Load Balancer Security Group"
  value       = module.security_group.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 Auto Scaling Group Security Group"
  value       = module.security_group.ec2_security_group_id
}

output "rds_security_group_id" {
  description = "The ID of the Amazon RDS Security Group"
  value       = module.security_group.rds_security_group_id
}

output "elasticache_security_group_id" {
  description = "The ID of the Amazon ElastiCache Redis Security Group"
  value       = module.security_group.elasticache_security_group_id
}

# ------------------------------------------------------------------------------
# Application Load Balancer Outputs
# ------------------------------------------------------------------------------

output "alb_dns_name" {
  description = "The public DNS hostname of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = module.alb.target_group_arn
}

output "application_url" {
  description = "The public web entry point for ShopSphere through the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "The URL for health checks across the balanced instance fleet"
  value       = "http://${module.alb.alb_dns_name}/health"
}

output "cache_stats_url" {
  description = "The URL to inspect real-time ElastiCache hit/miss statistics"
  value       = "http://${module.alb.alb_dns_name}/api/cache/stats"
}

# ------------------------------------------------------------------------------
# Auto Scaling Group Outputs
# ------------------------------------------------------------------------------

output "asg_name" {
  description = "The name of the EC2 Auto Scaling Group"
  value       = module.asg.asg_name
}

output "asg_id" {
  description = "The ID of the EC2 Auto Scaling Group"
  value       = module.asg.asg_id
}

output "asg_desired_capacity" {
  description = "The desired number of running EC2 instances in the ASG"
  value       = module.asg.desired_capacity
}

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template powering the ASG"
  value       = module.asg.launch_template_id
}

# ------------------------------------------------------------------------------
# Amazon RDS Database Tier Outputs
# ------------------------------------------------------------------------------

output "rds_endpoint" {
  description = "The connection endpoint for Amazon RDS PostgreSQL (host:port)"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "The hostname / DNS address of the Amazon RDS PostgreSQL instance"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "The port of the Amazon RDS PostgreSQL instance"
  value       = module.rds.db_instance_port
}

output "rds_db_name" {
  description = "The database name on Amazon RDS"
  value       = module.rds.db_instance_name
}

# ------------------------------------------------------------------------------
# Amazon ElastiCache Redis Tier Outputs
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Verification Helper Commands
# ------------------------------------------------------------------------------

output "cache_verification_command" {
  description = "Run twice to observe CACHE MISS on first query, then instant CACHE HIT on subsequent query"
  value       = "curl -i -s http://${module.alb.alb_dns_name}/api/products | grep -E 'X-Cache|latencyMs|source'"
}
