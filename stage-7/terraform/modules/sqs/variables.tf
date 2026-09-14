# ==============================================================================
# SQS Module Variables — Stage 5
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "queue_name" {
  description = "Name override for the main order processing queue (defaults to shopsphere-<env>-order-processing-queue)"
  type        = string
  default     = ""
}

variable "dlq_name" {
  description = "Name override for the dead letter queue (defaults to shopsphere-<env>-order-processing-dlq)"
  type        = string
  default     = ""
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue in seconds (must be >= Lambda timeout)"
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message (default: 4 days = 345600)"
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message in DLQ (default: 14 days = 1209600)"
  type        = number
  default     = 1209600
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it (default: 256 KB)"
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive (long polling, default: 10s)"
  type        = number
  default     = 10
}

variable "max_receive_count" {
  description = "The number of times a message is delivered to the source queue before being moved to the dead-letter queue"
  type        = number
  default     = 3
}

variable "sqs_managed_sse_enabled" {
  description = "Whether to enable SQS-managed server-side encryption (SSE-SQS)"
  type        = bool
  default     = true
}

variable "kms_master_key_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SQS or a custom CMK (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
