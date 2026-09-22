variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "stage10"
}

variable "argocd_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.7.16"
}

variable "gitops_repo_url" {
  description = "Git repository URL containing Kubernetes desired state manifests."
  type        = string
  default     = "https://github.com/vinodk11/shopsphere-aws-scaling-gitops.git"
}

variable "gitops_branch" {
  description = "Target Git branch in the GitOps repository"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path within the GitOps repository for production manifests"
  type        = string
  default     = "environments/production"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
