# ==============================================================================
# Outputs — Stage 5 (Amazon SQS + AWS Lambda Asynchronous Processing)
# ==============================================================================

# ------------------------------------------------------------------------------
# Messaging & Serverless Asynchronous Processing Outputs (Stage 5)
# ------------------------------------------------------------------------------

output "sqs_queue_url" {
  description = "URL of the primary SQS order processing queue"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the primary SQS order processing queue"
  value       = module.sqs.queue_arn
}

output "sqs_queue_name" {
  description = "Name of the primary SQS order processing queue"
  value       = module.sqs.queue_name
}

output "sqs_dlq_url" {
  description = "URL of the dead-letter queue (DLQ)"
  value       = module.sqs.dlq_url
}

output "sqs_dlq_arn" {
  description = "ARN of the dead-letter queue (DLQ)"
  value       = module.sqs.dlq_arn
}

output "sqs_dlq_name" {
  description = "Name of the dead-letter queue (DLQ)"
  value       = module.sqs.dlq_name
}

output "lambda_function_name" {
  description = "Name of the order processor Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the order processor Lambda function"
  value       = module.lambda.function_arn
}

output "lambda_cloudwatch_log_group" {
  description = "CloudWatch log group for the order processor Lambda function"
  value       = module.lambda.log_group_name
}

output "lambda_iam_role_arn" {
  description = "ARN of the Lambda IAM Role with SQS consume permissions"
  value       = module.iam.lambda_role_arn
}

output "ec2_sqs_policy_arn" {
  description = "ARN of the EC2 IAM policy permitting SQS publish"
  value       = module.iam.ec2_sqs_policy_arn
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer from Stage 3"
  value       = local.alb_dns_name
}

output "application_url" {
  description = "HTTP URL to access ShopSphere via Application Load Balancer"
  value       = local.alb_dns_name != "" ? "http://${local.alb_dns_name}" : ""
}
