# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 1)
# ==============================================================================

output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = module.vpc.vpc_id
}

output "subnet_id" {
  description = "The ID of the primary public subnet where the EC2 instance is deployed"
  value       = module.vpc.public_subnet_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across Multi-AZ"
  value       = module.vpc.public_subnet_ids
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs for Amazon RDS (for Stage 2+)"
  value       = module.vpc.private_db_subnet_ids
}

output "private_cache_subnet_ids" {
  description = "List of private cache subnet IDs for Amazon ElastiCache Redis (for Stage 4+)"
  value       = module.vpc.private_cache_subnet_ids
}

output "security_group_id" {
  description = "The ID of the ShopSphere EC2 Security Group"
  value       = module.security_group.security_group_id
}

output "ec2_instance_id" {
  description = "The ID of the ShopSphere EC2 instance"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "The private IPv4 address of the EC2 instance"
  value       = module.ec2.private_ip
}

output "ec2_public_ip" {
  description = "The public IPv4 address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "application_url" {
  description = "The public URL to access the ShopSphere e-commerce storefront"
  value       = "http://${module.ec2.public_ip}"
}

output "health_check_url" {
  description = "The URL for application and database health checks"
  value       = "http://${module.ec2.public_ip}/health"
}

output "ssh_connection_command" {
  description = "Example SSH connection command (replace key path if configured)"
  value       = var.ssh_key_name != null ? "ssh -i <path-to-${var.ssh_key_name}.pem> ec2-user@${module.ec2.public_ip}" : "SSM Session Manager: aws ssm start-session --target ${module.ec2.instance_id}"
}
