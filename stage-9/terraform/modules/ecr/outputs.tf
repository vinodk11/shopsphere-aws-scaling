output "repository_urls" {
  description = "Map of microservice name to ECR repository URL"
  value = {
    for k, v in aws_ecr_repository.microservices : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of microservice name to ECR repository ARN"
  value = {
    for k, v in aws_ecr_repository.microservices : k => v.arn
  }
}

output "product_repository_url" {
  description = "ECR Repository URL for Product Service"
  value       = aws_ecr_repository.microservices["product"].repository_url
}

output "order_repository_url" {
  description = "ECR Repository URL for Order Service"
  value       = aws_ecr_repository.microservices["order"].repository_url
}

output "frontend_repository_url" {
  description = "ECR Repository URL for Frontend Service"
  value       = aws_ecr_repository.microservices["frontend"].repository_url
}

output "user_repository_url" {
  description = "ECR Repository URL for User Service"
  value       = aws_ecr_repository.microservices["user"].repository_url
}
