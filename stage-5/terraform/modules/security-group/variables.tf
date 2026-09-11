# ==============================================================================
# Security Group Module Variables - Stage 4
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage4, dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created"
  type        = string
}

variable "http_ingress_cidr" {
  description = "CIDR blocks allowed for public HTTP ingress to ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_ingress_cidr" {
  description = "CIDR blocks allowed for public HTTPS ingress to ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidr" {
  description = "CIDR blocks allowed for SSH access to EC2 instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_port" {
  description = "Port for the PostgreSQL database"
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Port for the Redis cache cluster"
  type        = number
  default     = 6379
}

variable "tags" {
  description = "Tags to attach to security group resources"
  type        = map(string)
  default     = {}
}
