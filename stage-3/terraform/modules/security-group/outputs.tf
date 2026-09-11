# ==============================================================================
# Security Group Module Outputs - Stage 3
# ==============================================================================

output "alb_security_group_id" {
  description = "The ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 Auto Scaling Group security group"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "The ID of the Amazon RDS security group"
  value       = aws_security_group.rds.id
}
