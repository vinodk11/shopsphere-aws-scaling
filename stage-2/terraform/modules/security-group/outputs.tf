# ==============================================================================
# Security Group Module Outputs
# ==============================================================================

output "ec2_security_group_id" {
  description = "The ID of the EC2 Instance Security Group"
  value       = aws_security_group.ec2.id
}

output "ec2_security_group_name" {
  description = "The name of the EC2 Instance Security Group"
  value       = aws_security_group.ec2.name
}

output "rds_security_group_id" {
  description = "The ID of the Amazon RDS Security Group"
  value       = aws_security_group.rds.id
}

output "rds_security_group_name" {
  description = "The name of the Amazon RDS Security Group"
  value       = aws_security_group.rds.name
}
