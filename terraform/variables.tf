variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming and tagging"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Environment name (e.g., stage1, dev, prod)"
  type        = string
  default     = "stage1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of the root EBS volume (e.g., gp3, gp2)"
  type        = string
  default     = "gp3"
}

variable "admin_cidr" {
  description = "List of CIDR blocks allowed SSH access. Use your public IP /32 (e.g., [\"203.0.113.10/32\"])"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access. Leave empty to rely on SSM Session Manager only"
  type        = string
  default     = null
}

variable "app_repo_url" {
  description = "Git URL of the ShopSphere application repository"
  type        = string
  default     = "https://github.com/kbhujbal/ShopSphere---E-commerce-Microservice-Platform.git"
}

variable "app_branch" {
  description = "Git branch to clone"
  type        = string
  default     = "main"
}

variable "db_username" {
  description = "MongoDB admin username. NOTE: move to AWS Secrets Manager in future stages"
  type        = string
  sensitive   = true
  default     = "shopsphere_admin"
}

variable "db_password" {
  description = "MongoDB admin password. NOTE: move to AWS Secrets Manager in future stages"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret for the application. NOTE: move to AWS Secrets Manager in future stages"
  type        = string
  sensitive   = true
}

variable "app_port" {
  description = "Port the ShopSphere API Gateway listens on"
  type        = number
  default     = 8080
}

variable "reverse_proxy_port" {
  description = "Port Nginx listens on as reverse proxy"
  type        = number
  default     = 80
}