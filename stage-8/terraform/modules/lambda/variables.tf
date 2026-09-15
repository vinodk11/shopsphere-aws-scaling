# ==============================================================================
# Lambda Module Variables — Stage 5
# ==============================================================================

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Name of the Lambda function (defaults to shopsphere-<env>-order-processor)"
  type        = string
  default     = ""
}

variable "lambda_role_arn" {
  description = "IAM Role ARN for Lambda execution"
  type        = string
}

variable "source_dir" {
  description = "Path to directory containing Lambda source code"
  type        = string
}

variable "handler" {
  description = "Lambda function handler entrypoint"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda execution runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "timeout" {
  description = "Lambda function execution timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Amount of memory in MB allocated to Lambda function"
  type        = number
  default     = 256
}

variable "sqs_queue_arn" {
  description = "ARN of SQS queue for event source mapping trigger"
  type        = string
}

variable "batch_size" {
  description = "The maximum number of records to retrieve in a single batch from SQS"
  type        = number
  default     = 10
}

variable "maximum_batching_window_in_seconds" {
  description = "The maximum amount of time in seconds to gather records before invoking the function"
  type        = number
  default     = 5
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "environment_variables" {
  description = "Map of environment variables to configure in the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
