# ==============================================================================
# VPC Module Variables - Stage 4 Multi-AZ Networking
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage4, dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (ALB and ASG compute tier across at least 2 AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_availability_zones" {
  description = "List of AWS Availability Zones for the public subnets"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "List of CIDR blocks for private database subnets (RDS PostgreSQL)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_cache_subnet_cidrs" {
  description = "List of CIDR blocks for private cache subnets (Amazon ElastiCache Redis)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "private_availability_zones" {
  description = "List of AWS Availability Zones for the private subnets"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all VPC resources"
  type        = map(string)
  default     = {}
}
