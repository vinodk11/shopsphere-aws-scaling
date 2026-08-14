variable "project_name" {
  description = "Project name used for naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., stage1, dev, prod)"
  type        = string
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

  constraint {
    description = "Must be a valid AWS AZ in the provider region"
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type = object({
    Project     = string
    Environment = string
    ManagedBy   = string
  })
}