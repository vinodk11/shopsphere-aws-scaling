# ==============================================================================
# IAM Module Variables — Stage 5
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for IAM resources"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "sqs_queue_arn" {
  description = "ARN of the primary SQS order processing queue"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
