# ==============================================================================
# Outputs — Stage 8 (Amazon ECR Container Registry & Edge Delivery)
# ==============================================================================

output "ecr_repository_url" {
  description = "URL of the Amazon ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the Amazon ECR repository"
  value       = module.ecr.repository_name
}

output "ecr_repository_arn" {
  description = "ARN of the Amazon ECR repository"
  value       = module.ecr.repository_arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = local.asg_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = local.asg_name
}

output "launch_template_id" {
  description = "ID of the EC2 Launch Template"
  value       = local.launch_template_id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = local.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = local.target_group_arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront CDN distribution"
  value       = local.cloudfront_domain_name
}

output "cloudfront_url" {
  description = "URL of the CloudFront distribution"
  value       = local.cloudfront_domain_name != "" ? "https://${local.cloudfront_domain_name}" : ""
}
