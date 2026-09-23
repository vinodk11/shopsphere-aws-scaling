# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 2 - Decoupled Amazon RDS)
# ==============================================================================

# ------------------------------------------------------------------------------
# Discovered Stage 1 Foundation Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the persistent ShopSphere VPC discovered from Stage 1"
  value       = local.vpc_id
}

output "stage1_ec2_instance_id" {
  description = "The ID of the running Stage 1 EC2 monolith server"
  value       = try(data.aws_instances.stage1_ec2.ids[0], "pending")
}

output "stage1_ec2_public_ip" {
  description = "The public IPv4 address of the Stage 1 EC2 instance"
  value       = try(data.aws_instances.stage1_ec2.public_ips[0], "pending")
}

output "application_url" {
  description = "The public web URL of the ShopSphere storefront"
  value       = length(try(data.aws_instances.stage1_ec2.public_ips, [])) > 0 ? "http://${data.aws_instances.stage1_ec2.public_ips[0]}" : "Discovering..."
}

output "health_check_url" {
  description = "The URL for application health check"
  value       = length(try(data.aws_instances.stage1_ec2.public_ips, [])) > 0 ? "http://${data.aws_instances.stage1_ec2.public_ips[0]}/health" : "Discovering..."
}

# ------------------------------------------------------------------------------
# Amazon RDS Database Tier Outputs (Provisioned in Stage 2)
# ------------------------------------------------------------------------------

output "rds_security_group_id" {
  description = "The ID of the Amazon RDS Security Group"
  value       = aws_security_group.rds.id
}

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

output "connect_ec2_command" {
  description = "Run this helper script to connect the Stage 1 EC2 monolith to the new Amazon RDS instance"
  value       = "./scripts/connect_ec2_to_rds.sh"
}
