# ==============================================================================
# RDS Module Variables - Stage 4
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage4, dev, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS DB Subnet Group"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security Group ID allowing inbound PostgreSQL traffic from EC2"
  type        = string
}

variable "db_name" {
  description = "Name of the initial PostgreSQL database to create"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "Master username for the PostgreSQL database"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "Master password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port on which the database accepts connections"
  type        = number
  default     = 5432
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}

variable "instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage limit in GB for autoscaling"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type for the RDS instance"
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "Specifies if the RDS instance is deployed across multiple AZs"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the database is publicly accessible over the internet"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily time range during which automated backups are created"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly time range during which system maintenance can occur"
  type        = string
  default     = "Sun:04:30-Sun:05:30"
}

variable "skip_final_snapshot" {
  description = "Whether to skip creating a final snapshot before deleting the DB instance"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled on the RDS instance"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to RDS resources"
  type        = map(string)
  default     = {}
}
