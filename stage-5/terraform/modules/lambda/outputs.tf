# ==============================================================================
# Lambda Module Outputs — Stage 5
# ==============================================================================

output "function_arn" {
  description = "ARN of the order processor Lambda function"
  value       = aws_lambda_function.order_processor.arn
}

output "function_name" {
  description = "Name of the order processor Lambda function"
  value       = aws_lambda_function.order_processor.function_name
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "event_source_mapping_uuid" {
  description = "The UUID of the SQS event source mapping"
  value       = aws_lambda_event_source_mapping.sqs_trigger.uuid
}
