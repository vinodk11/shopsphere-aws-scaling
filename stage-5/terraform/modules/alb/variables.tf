# ==============================================================================
# ALB Module Variables - Stage 4
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
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs across at least 2 Availability Zones"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "health_check_path" {
  description = "Health check request path for the target group"
  type        = string
  default     = "/health"
}

variable "tags" {
  description = "Tags to attach to ALB resources"
  type        = map(string)
  default     = {}
}
