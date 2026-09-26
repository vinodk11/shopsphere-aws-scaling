# ==============================================================================
# Global & Environment Variables - Stage 3 (ALB + ASG + Multi-EC2 + Amazon RDS)
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
  default     = "stage3"
}

variable "vpc_id" {
  description = "Optional existing VPC ID from Stage 1 (if empty, dynamically discovered via tags)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Optional list of public subnet IDs (if empty, dynamically discovered from Stage 1)"
  type        = list(string)
  default     = []
}

variable "db_host" {
  description = "Optional Amazon RDS database host override (if empty, discovered from Stage 2)"
  type        = string
  default     = ""
}

variable "db_instance_identifier" {
  description = "Optional Amazon RDS database instance identifier (default: shopsphere-stage2-postgres)"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Port on which the database accepts connections"
  type        = number
  default     = 5432
}

variable "rds_security_group_id" {
  description = "Optional existing Stage 2 RDS security group ID (if empty, dynamically discovered)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "The CIDR block for the dedicated ShopSphere VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks for public subnets (ALB and EC2 ASG tier across multi-AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks for private subnets (Amazon RDS Tier across multi-AZ)"
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
  description = "List of IPv4 CIDR blocks authorized for SSH administrative access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# EC2 Auto Scaling & Compute Variables
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

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_target_cpu_utilization" {
  description = "Target CPU utilization percentage for dynamic auto-scaling"
  type        = number
  default     = 70.0
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
  default     = "https://github.com/vinodk11/shopsphere-aws-scaling.git"
}

# ------------------------------------------------------------------------------
# Amazon RDS PostgreSQL Database Variables
# ------------------------------------------------------------------------------

variable "db_name" {
  description = "The database name to create on Amazon RDS"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "The master username for Amazon RDS PostgreSQL"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "The master password for Amazon RDS PostgreSQL (set via terraform.tfvars or TF_VAR_db_password)"
  type        = string
  sensitive   = true
  default     = "ShopSphere2026SecurePass!"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version on Amazon RDS"
  type        = string
  default     = "15.7"
}

variable "db_instance_class" {
  description = "The instance class for Amazon RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Upper storage auto-scaling threshold in GB for RDS"
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ synchronous standby replica for RDS"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip creating final RDS snapshot during destruction (recommended for lab/dev environments)"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated daily backups"
  type        = number
  default     = 7
}
