# ==============================================================================
# Outputs — Stage 5 (SQS + AWS Lambda + ElastiCache Redis + RDS + ALB + ASG)
# ==============================================================================

# ------------------------------------------------------------------------------
# Ingress & Compute Fleet Outputs
# ------------------------------------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "application_url" {
  description = "HTTP URL to access ShopSphere via Application Load Balancer"
  value       = module.alb.alb_url
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = module.alb.target_group_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.asg.asg_name
}

# ------------------------------------------------------------------------------
# Database & Cache Outputs
# ------------------------------------------------------------------------------

output "rds_endpoint" {
  description = "Connection endpoint of Amazon RDS PostgreSQL"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "Hostname of Amazon RDS PostgreSQL"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "Database port for Amazon RDS PostgreSQL"
  value       = module.rds.db_instance_port
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "redis_endpoint" {
  description = "Primary endpoint address for Amazon ElastiCache Redis"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "Port number for Amazon ElastiCache Redis"
  value       = module.elasticache.redis_port
}

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

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM Role with SQS publish permissions"
  value       = module.iam.ec2_role_arn
}

output "lambda_iam_role_arn" {
  description = "ARN of the Lambda IAM Role with SQS consume permissions"
  value       = module.iam.lambda_role_arn
}
