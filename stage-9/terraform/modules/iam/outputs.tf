output "aws_load_balancer_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "order_service_sqs_role_arn" {
  description = "IAM Role ARN for EKS Order Service SQS Publisher"
  value       = aws_iam_role.order_service_sqs.arn
}
