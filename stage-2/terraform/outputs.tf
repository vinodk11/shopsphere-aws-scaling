# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 2 - Decoupled Amazon RDS)
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "The ID of the public subnet hosting the EC2 compute instance"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets hosting the Amazon RDS database"
  value       = module.vpc.private_subnet_ids
}

# ------------------------------------------------------------------------------
# Security Group Outputs
# ------------------------------------------------------------------------------

output "ec2_security_group_id" {
  description = "The ID of the EC2 Instance Security Group"
  value       = module.security_group.ec2_security_group_id
}

output "rds_security_group_id" {
  description = "The ID of the Amazon RDS Security Group"
  value       = module.security_group.rds_security_group_id
}

# ------------------------------------------------------------------------------
# EC2 Compute Tier Outputs
# ------------------------------------------------------------------------------

output "ec2_instance_id" {
  description = "The ID of the ShopSphere EC2 application instance"
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
  description = "The public web URL to access the ShopSphere application"
  value       = "http://${module.ec2.public_ip}"
}

output "health_check_url" {
  description = "The URL for application and RDS database health checks"
  value       = "http://${module.ec2.public_ip}/health"
}

output "ssh_connection_command" {
  description = "Example SSH connection command or SSM session command"
  value       = var.ssh_key_name != null ? "ssh -i <path-to-${var.ssh_key_name}.pem> ec2-user@${module.ec2.public_ip}" : "aws ssm start-session --target ${module.ec2.instance_id}"
}

# ------------------------------------------------------------------------------
# Amazon RDS Database Tier Outputs
# ------------------------------------------------------------------------------

output "rds_endpoint" {
  description = "The connection endpoint for Amazon RDS PostgreSQL (host:port)"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "The hostname / DNS address of the Amazon RDS PostgreSQL instance"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "The port of the Amazon RDS PostgreSQL instance"
  value       = module.rds.db_instance_port
}

output "rds_db_name" {
  description = "The database name on Amazon RDS"
  value       = module.rds.db_instance_name
}

output "rds_instance_id" {
  description = "The identifier of the Amazon RDS instance"
  value       = module.rds.db_instance_id
}
