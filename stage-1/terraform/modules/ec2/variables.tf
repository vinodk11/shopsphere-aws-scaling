variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage1, dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Public subnet ID where the EC2 instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID to associate with the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Optional EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type (e.g., gp3, gp2)"
  type        = string
  default     = "gp3"
}

variable "user_data" {
  description = "User data script to bootstrap the EC2 instance"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to the EC2 instance and attached resources"
  type        = map(string)
  default     = {}
}
