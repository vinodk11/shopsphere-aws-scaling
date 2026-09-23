# ==============================================================================
# Global & Environment Variables — Stage 7 (DevSecOps CI/CD Automation)
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region"
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
  default     = "stage7"
}

# ------------------------------------------------------------------------------
# Discovery & Override Inputs from Stages 1-6
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "Optional existing VPC ID from Stage 1"
  type        = string
  default     = ""
}

variable "asg_name" {
  description = "Optional existing Auto Scaling Group name from Stage 3"
  type        = string
  default     = ""
}

variable "launch_template_id" {
  description = "Optional existing Launch Template ID from Stage 3"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "Optional existing ALB ARN from Stage 3"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "Optional existing ALB DNS name from Stage 3"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "Optional existing ALB Target Group ARN from Stage 3"
  type        = string
  default     = ""
}

variable "cloudfront_domain_name" {
  description = "Optional existing CloudFront domain name from Stage 6"
  type        = string
  default     = ""
}
