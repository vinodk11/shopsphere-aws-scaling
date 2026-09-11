# ==============================================================================
# VPC Module Variables - Stage 3 Multi-AZ Networking
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage3, dev, prod)"
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
  description = "List of AWS Availability Zones for the public subnets (must match public_subnet_cidrs length)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for the private subnets (Amazon RDS Database Tier - requires at least 2 AZs)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_availability_zones" {
  description = "List of AWS Availability Zones for the private subnets (must match private_subnet_cidrs length)"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all VPC resources"
  type        = map(string)
  default     = {}
}
