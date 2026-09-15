variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "shopsphere"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "prod"
}

variable "repository_name" {
  type        = string
  description = "ECR repository name"
  default     = ""
}

variable "image_tag_mutability" {
  type        = string
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Enable vulnerability scanning on image push"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
