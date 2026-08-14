variable "project_name" {
  description = "Project name used for naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., stage1, dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = null
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

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
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
  description = "MongoDB admin username (move to AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "MongoDB admin password (move to AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret for the application (move to AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "app_port" {
  description = "Port the ShopSphere application listens on"
  type        = number
  default     = 8080
}

variable "reverse_proxy_port" {
  description = "Port Nginx listens on (reverse proxy)"
  type        = number
  default     = 80
}
