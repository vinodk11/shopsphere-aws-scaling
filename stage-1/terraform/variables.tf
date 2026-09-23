# ==============================================================================
# Global & Environment Variables
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
  default     = "stage1"
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
  description = "Fallback single CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (Multi-AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "List of CIDR blocks for private database subnets (Amazon RDS across Multi-AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_cache_subnet_cidrs" {
  description = "List of CIDR blocks for private cache subnets (Amazon ElastiCache Redis across Multi-AZ)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "availability_zone" {
  description = "Single Availability Zone fallback"
  type        = string
  default     = null
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
  description = "EC2 instance size for the monolithic server"
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
# Application & Database Configuration Variables
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

variable "db_name" {
  description = "Name of the local PostgreSQL database for ShopSphere"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "Username for the local PostgreSQL database"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "Password for the local PostgreSQL database user (Note: will migrate to AWS Secrets Manager in Stage 2+)"
  type        = string
  sensitive   = true
  default     = "ShopSphere2026SecurePass!"
}
