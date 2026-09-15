# ==============================================================================
# Outputs — Stage 6 (CloudFront + WAF + SQS + Lambda + Redis + RDS + ALB + ASG)
# ==============================================================================

# ------------------------------------------------------------------------------
# Edge CDN & Perimeter Security Outputs (Stage 6)
# ------------------------------------------------------------------------------

output "cloudfront_url" {
  description = "Primary HTTPS URL to access ShopSphere globally via Amazon CloudFront"
  value       = module.cloudfront.cloudfront_url
}

output "cloudfront_domain_name" {
  description = "Domain name of the Amazon CloudFront CDN distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "Identifier of the Amazon CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "waf_web_acl_name" {
  description = "Name of the AWS WAF v2 Web ACL protecting CloudFront"
  value       = module.waf.web_acl_name
}

output "waf_web_acl_arn" {
  description = "ARN of the AWS WAF v2 Web ACL protecting CloudFront"
  value       = module.waf.web_acl_arn
}

# ------------------------------------------------------------------------------
# Ingress & Compute Fleet Outputs
# ------------------------------------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer (Origin)"
  value       = module.alb.alb_dns_name
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

output "redis_endpoint" {
  description = "Primary endpoint address for Amazon ElastiCache Redis"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "Port number for Amazon ElastiCache Redis"
  value       = module.elasticache.redis_port
}

# ------------------------------------------------------------------------------
# Messaging & Serverless Asynchronous Processing Outputs
# ------------------------------------------------------------------------------

output "sqs_queue_url" {
  description = "URL of the primary SQS order processing queue"
  value       = module.sqs.queue_url
}

output "sqs_dlq_url" {
  description = "URL of the dead-letter queue (DLQ)"
  value       = module.sqs.dlq_url
}

output "lambda_function_name" {
  description = "Name of the order processor Lambda function"
  value       = module.lambda.function_name
}

output "lambda_cloudwatch_log_group" {
  description = "CloudWatch log group for the order processor Lambda function"
  value       = module.lambda.log_group_name
}

# ------------------------------------------------------------------------------
# Container Registry Outputs (Stage 8)
# ------------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL of the Amazon ECR Docker repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the Amazon ECR Docker repository"
  value       = module.ecr.repository_name
}
