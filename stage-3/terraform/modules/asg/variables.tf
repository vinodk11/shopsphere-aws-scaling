# ==============================================================================
# ASG Module Variables - Stage 3
# ==============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage3, dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 launch template"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size for the application server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional name of existing AWS EC2 KeyPair for SSH"
  type        = string
  default     = null
}

variable "security_group_id" {
  description = "The ID of the EC2 security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register instances with"
  type        = string
}

variable "user_data" {
  description = "Rendered user_data cloud-init script for EC2 instances"
  type        = string
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Storage type of the root EBS volume"
  type        = string
  default     = "gp3"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization percentage for dynamic autoscaling"
  type        = number
  default     = 70.0
}

variable "tags" {
  description = "Tags to attach to resources"
  type        = map(string)
  default     = {}
}
