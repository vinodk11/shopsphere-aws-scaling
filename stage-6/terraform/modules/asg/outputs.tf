# ==============================================================================
# ASG Module Outputs - Stage 4
# ==============================================================================

output "asg_id" {
  description = "The Auto Scaling Group ID"
  value       = aws_autoscaling_group.this.id
}

output "asg_name" {
  description = "The Auto Scaling Group name"
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "The Auto Scaling Group ARN"
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template"
  value       = aws_launch_template.this.id
}

output "launch_template_arn" {
  description = "The ARN of the EC2 Launch Template"
  value       = aws_launch_template.this.arn
}

output "min_size" {
  description = "The minimum configured instance count in ASG"
  value       = aws_autoscaling_group.this.min_size
}

output "max_size" {
  description = "The maximum configured instance count in ASG"
  value       = aws_autoscaling_group.this.max_size
}

output "desired_capacity" {
  description = "The desired instance count in ASG"
  value       = aws_autoscaling_group.this.desired_capacity
}
