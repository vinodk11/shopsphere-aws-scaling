# ==============================================================================
# IAM Module Outputs — Stage 5
# ==============================================================================

output "lambda_role_arn" {
  description = "ARN of the AWS Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the AWS Lambda execution role"
  value       = aws_iam_role.lambda.name
}

output "ec2_sqs_policy_arn" {
  description = "ARN of the EC2 SQS publish IAM policy"
  value       = aws_iam_policy.ec2_sqs_publish.arn
}
