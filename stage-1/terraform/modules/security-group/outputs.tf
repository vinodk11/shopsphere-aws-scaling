output "security_group_id" {
  description = "The ID of the ShopSphere EC2 Security Group"
  value       = aws_security_group.ec2.id
}

output "security_group_name" {
  description = "The name of the ShopSphere EC2 Security Group"
  value       = aws_security_group.ec2.name
}
