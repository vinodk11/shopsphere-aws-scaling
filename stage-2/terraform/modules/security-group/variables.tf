# ==============================================================================
# Security Group Module Variables - Stage 2
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage2, dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR blocks allowed for SSH administrative access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "http_ingress_cidr" {
  description = "CIDR blocks allowed for HTTP (port 80) access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_ingress_cidr" {
  description = "CIDR blocks allowed for HTTPS (port 443) access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_port" {
  description = "PostgreSQL port for RDS inbound traffic"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags applied to security groups"
  type        = map(string)
  default     = {}
}
