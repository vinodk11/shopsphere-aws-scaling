# ==============================================================================
# Global & Environment Variables - Stage 4 (ElastiCache Redis In-Memory Caching)
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region to deploy ShopSphere resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "The deployment environment stage"
  type        = string
  default     = "stage4"
}

# ------------------------------------------------------------------------------
# Discovery & Override Inputs from Stages 1-3
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "Optional existing VPC ID from Stage 1 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

variable "cache_subnet_ids" {
  description = "Optional existing private cache subnet IDs from Stage 1 (if empty, dynamically discovered via tags)"
  type        = list(string)
  default     = []
}

variable "asg_security_group_id" {
  description = "Optional EC2 ASG security group ID from Stage 3 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "Optional ARN of the Application Load Balancer from Stage 3 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "Optional DNS name of the Application Load Balancer from Stage 3 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Amazon ElastiCache Redis Variables
# ------------------------------------------------------------------------------

variable "cache_node_type" {
  description = "The compute and memory instance type for ElastiCache Redis nodes"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "The Redis caching engine version"
  type        = string
  default     = "7.0"
}

variable "redis_port" {
  description = "The port on which the Redis cluster accepts TCP connections"
  type        = number
  default     = 6379
}

# ------------------------------------------------------------------------------
# Security Variables
# ------------------------------------------------------------------------------

variable "admin_cidr" {
  description = "List of IPv4 CIDR blocks authorized for administrative access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
