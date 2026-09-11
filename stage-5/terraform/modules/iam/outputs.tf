# ==============================================================================
# IAM Module Outputs — Stage 5
# ==============================================================================

output "ec2_role_arn" {
  description = "ARN of the EC2 ASG IAM role"
  value       = aws_iam_role.ec2.arn
}

output "ec2_role_name" {
  description = "Name of the EC2 ASG IAM role"
  value       = aws_iam_role.ec2.name
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 IAM instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "lambda_role_arn" {
  description = "ARN of the AWS Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the AWS Lambda execution role"
  value       = aws_iam_role.lambda.name
}
