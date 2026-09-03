variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., stage1, dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR blocks allowed for SSH administrative access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "http_ingress_cidr" {
  description = "CIDR blocks allowed for HTTP (port 80) access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_ingress_cidr" {
  description = "CIDR blocks allowed for HTTPS (port 443) access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Common tags applied to the security group"
  type        = map(string)
  default     = {}
}
