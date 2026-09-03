# ==============================================================================
# RDS Module Outputs
# ==============================================================================

output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.this.identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_address" {
  description = "The hostname / connection endpoint address of the RDS database"
  value       = aws_db_instance.this.address
}

output "db_instance_endpoint" {
  description = "The connection endpoint in address:port format"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.this.port
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.this.resource_id
}

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.this.id
}
