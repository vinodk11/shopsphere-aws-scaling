# ==============================================================================
# Global & Environment Variables - Stage 2 (Amazon RDS Decoupling)
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region to deploy ShopSphere resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "The deployment environment stage"
  type        = string
  default     = "stage2"
}

# ------------------------------------------------------------------------------
# Network Variables
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "The CIDR block for the dedicated ShopSphere VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet (EC2 Compute Tier)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks for the private subnets (Amazon RDS Tier across multi-AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Explicit list of Availability Zones to use (leave null to dynamically select first 2 AZs in region)"
  type        = list(string)
  default     = null
}

# ------------------------------------------------------------------------------
# Security Variables
# ------------------------------------------------------------------------------

variable "admin_cidr" {
  description = "List of IPv4 CIDR blocks authorized for SSH administrative access (e.g. ['203.0.113.50/32'])"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# EC2 Compute & Storage Variables
# ------------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance size for the application server"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size of the encrypted root EBS volume in GB"
  type        = number
  default     = 20
}

variable "ssh_key_name" {
  description = "Optional name of existing AWS EC2 KeyPair for SSH key-based access"
  type        = string
  default     = null
}

variable "custom_ami_id" {
  description = "Optional custom AMI ID override (if omitted, latest Amazon Linux 2023 is resolved dynamically)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Application Configuration Variables
# ------------------------------------------------------------------------------

variable "app_port" {
  description = "Internal listening port for the ShopSphere application server"
  type        = number
  default     = 8080
}

variable "app_repo_url" {
  description = "Git repository URL to clone ShopSphere application source from"
  type        = string
  default     = "https://github.com/kbhujbal/ShopSphere---E-commerce-Microservice-Platform.git"
}

# ------------------------------------------------------------------------------
# Amazon RDS Database Variables
# ------------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the initial PostgreSQL database on Amazon RDS"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "Master username for Amazon RDS PostgreSQL"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "Master password for Amazon RDS PostgreSQL"
  type        = string
  sensitive   = true
  default     = "ShopSphere2026SecurePass!"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for Amazon RDS"
  type        = string
  default     = "15.7"
}

variable "db_instance_class" {
  description = "RDS DB instance class for PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB for Amazon RDS"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage limit in GB for autoscaling (set > allocated_storage to enable)"
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for automatic failover and high availability"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final DB snapshot before deletion (set true for quick lab teardown)"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated DB backups"
  type        = number
  default     = 7
}
