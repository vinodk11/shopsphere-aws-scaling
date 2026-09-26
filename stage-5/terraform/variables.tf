# ==============================================================================
# Global & Environment Variables — Stage 5 (Amazon SQS + AWS Lambda)
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
  default     = "stage5"
}

# ------------------------------------------------------------------------------
# Discovery & Override Inputs from Stages 1-4
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "Optional existing VPC ID from Stage 1 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "Optional Amazon RDS endpoint hostname from Stage 2 (if empty, dynamically discovered)"
  type        = string
  default     = ""
}

variable "db_instance_identifier" {
  description = "Optional Amazon RDS database instance identifier (default: shopsphere-stage2-postgres)"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Port number for Amazon RDS PostgreSQL"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name on Amazon RDS"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "Database master username"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ec2_role_name" {
  description = "Optional name of the existing Stage 3 EC2 ASG IAM role"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "Optional ARN of the Application Load Balancer from Stage 3"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "Optional DNS name of the Application Load Balancer from Stage 3"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Amazon SQS Variables
# ------------------------------------------------------------------------------

variable "sqs_queue_name" {
  description = "Explicit name for the primary SQS queue"
  type        = string
  default     = ""
}

variable "sqs_dlq_name" {
  description = "Explicit name for the dead-letter queue (DLQ)"
  type        = string
  default     = ""
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout in seconds for messages in the main queue"
  type        = number
  default     = 300
}

variable "sqs_message_retention_seconds" {
  description = "Message retention period in seconds for the main queue"
  type        = number
  default     = 345600 # 4 days
}

variable "sqs_max_receive_count" {
  description = "Maximum deliveries before a poisoned message is redirected to the DLQ"
  type        = number
  default     = 5
}

variable "sqs_managed_sse_enabled" {
  description = "Enable SQS-managed server-side encryption (SSE-SQS)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# AWS Lambda Variables
# ------------------------------------------------------------------------------

variable "lambda_function_name" {
  description = "Explicit name for the order processing Lambda worker"
  type        = string
  default     = ""
}

variable "lambda_runtime" {
  description = "Runtime environment for the Lambda worker"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Execution timeout in seconds for the Lambda function"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 256
}

variable "lambda_batch_size" {
  description = "Maximum number of SQS records delivered to Lambda per invocation batch"
  type        = number
  default     = 10
}

variable "lambda_maximum_batching_window_in_seconds" {
  description = "Maximum time in seconds to gather records before invoking Lambda"
  type        = number
  default     = 5
}

variable "lambda_log_retention_in_days" {
  description = "Number of days to retain CloudWatch logs for the Lambda function"
  type        = number
  default     = 14
}
