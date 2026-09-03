output "instance_id" {
  description = "The ID of the ShopSphere EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "The private IPv4 address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "The public IPv4 address of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.this.public_dns
}

output "iam_role_arn" {
  description = "The ARN of the IAM role attached to the EC2 instance"
  value       = aws_iam_role.this.arn
}
