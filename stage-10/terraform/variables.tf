# ==============================================================================
# Variables — Stage 10 (GitOps & Argo CD on Amazon EKS)
# ==============================================================================

variable "aws_region" {
  description = "Target AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name identifier used for resource naming"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "stage10"
}

# ------------------------------------------------------------------------------
# Existing Infrastructure References
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "Existing VPC ID. If omitted, discovered automatically via tags"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of existing public/private subnets across Multi-AZ for EKS. If empty, auto-discovered"
  type        = list(string)
  default     = []
}

variable "alb_arn" {
  description = "ARN of the existing Application Load Balancer. If empty, auto-discovered via tags"
  type        = string
  default     = ""
}

variable "alb_listener_arn" {
  description = "ARN of the existing ALB HTTP Listener. If empty, auto-discovered"
  type        = string
  default     = ""
}

variable "stage8_target_group_arn" {
  description = "ARN of the existing Stage 8 EC2 ASG Target Group. If empty, auto-discovered"
  type        = string
  default     = ""
}

variable "rds_security_group_id" {
  description = "Security group ID of the existing RDS instance to allow EKS ingress. If empty, auto-discovered"
  type        = string
  default     = ""
}

variable "redis_security_group_id" {
  description = "Security group ID of the existing ElastiCache Redis cluster. If empty, auto-discovered"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "ARN of the existing SQS queue for order processing. If empty, auto-discovered"
  type        = string
  default     = ""
}

variable "custom_header_name" {
  description = "Header name for CloudFront origin verification"
  type        = string
  default     = "X-Origin-Verify"
}

variable "custom_header_value" {
  description = "Secret header value for CloudFront origin verification"
  type        = string
  default     = "ShopSphereEdgeSecretToken2026Verify"
  sensitive   = true
}

variable "db_host" {
  description = "Existing Stage 8 RDS endpoint used by Stage 10."
  type        = string
  default     = "shopsphere-stage8-postgres.cy9mak0su1oj.us-east-1.rds.amazonaws.com"
}

variable "redis_host" {
  description = "Existing Stage 8 ElastiCache Redis endpoint used by Stage 10."
  type        = string
  default     = "shopsphere-stage8-redis.ekxmke.0001.use1.cache.amazonaws.com"
}

variable "db_name" {
  type    = string
  default = "shopspheredb"
}

variable "db_user" {
  type    = string
  default = "shopsphere_user"
}

# ------------------------------------------------------------------------------
# EKS Cluster Sizing & Configuration
# ------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
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

variable "disk_size" {
  description = "Root disk volume size in GB for worker nodes"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# Blue/Green Traffic Migration Weights
# ------------------------------------------------------------------------------

variable "blue_weight" {
  description = "Traffic percentage routed to Stage 8 (Blue) Target Group"
  type        = number
  default     = 0
}

variable "green_weight" {
  description = "Traffic percentage routed to Stage 10 (Green) EKS Target Group"
  type        = number
  default     = 100
}

variable "enable_product_path_routing" {
  description = "Direct /api/products* traffic to EKS Product Service"
  type        = bool
  default     = true
}

variable "enable_order_path_routing" {
  description = "Direct /api/orders* traffic to EKS Order Service"
  type        = bool
  default     = true
}

variable "enable_user_path_routing" {
  description = "Direct /api/users* traffic to EKS User Service"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# GitOps & Argo CD Configuration
# ------------------------------------------------------------------------------

variable "gitops_repo_url" {
  description = "GitOps repository URL containing Kubernetes desired state"
  type        = string
  default     = "https://github.com/vinodk11/shopsphere-gitops.git"
}

variable "gitops_branch" {
  description = "Target branch in the GitOps repository"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path within the GitOps repository for production manifests"
  type        = string
  default     = "environments/production"
}

variable "tags" {
  description = "Additional tags for Stage 10 resources"
  type        = map(string)
  default     = {}
}
