variable "project_name" {
  description = "Project name identifier"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS Cluster OIDC Provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS Cluster OIDC Provider URL without protocol"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Target Kubernetes namespace for microservices"
  type        = string
  default     = "shopsphere"
}

variable "sqs_queue_arn" {
  description = "ARN of the Amazon SQS order queue"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Standard tags to assign to resources"
  type        = map(string)
  default     = {}
}
