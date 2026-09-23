# ==============================================================================
# IAM Module Variables — Stage 5
# ==============================================================================

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment stage"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the primary SQS order processing queue"
  type        = string
}

variable "ec2_role_name" {
  description = "Optional name of the existing Stage 3 EC2 ASG IAM role"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
