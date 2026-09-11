# ==============================================================================
# SQS Module Outputs — Stage 5
# ==============================================================================

output "queue_id" {
  description = "The URL of the main SQS order processing queue"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "The ARN of the main SQS order processing queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "The name of the main SQS order processing queue"
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "The URL of the main SQS order processing queue"
  value       = aws_sqs_queue.main.url
}

output "dlq_id" {
  description = "The URL of the dead-letter queue"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "The ARN of the dead-letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_name" {
  description = "The name of the dead-letter queue"
  value       = aws_sqs_queue.dlq.name
}

output "dlq_url" {
  description = "The URL of the dead-letter queue"
  value       = aws_sqs_queue.dlq.url
}
