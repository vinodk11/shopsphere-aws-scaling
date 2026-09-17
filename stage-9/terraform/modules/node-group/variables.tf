variable "project_name" {
  description = "Project name identifier"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security Group ID of the EKS control plane"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where worker nodes run"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for worker nodes across Multi-AZ"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security Group ID of the Application Load Balancer"
  type        = string
}

variable "rds_security_group_id" {
  description = "Security Group ID of the RDS PostgreSQL instance"
  type        = string
  default     = ""
}

variable "redis_security_group_id" {
  description = "Security Group ID of the ElastiCache Redis cluster"
  type        = string
  default     = ""
}

variable "instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Capacity type for worker nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Root disk size in GB for worker nodes"
  type        = number
  default     = 30
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Standard tags to assign to resources"
  type        = map(string)
  default     = {}
}
