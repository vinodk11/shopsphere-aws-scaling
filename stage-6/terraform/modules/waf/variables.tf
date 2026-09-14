# ==============================================================================
# AWS WAF v2 Module Variables — Stage 6
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment (e.g., stage6, dev, prod)"
  type        = string
  default     = "stage6"
}

variable "rate_limit" {
  description = "Rate-based rule limit: maximum requests per 5-minute evaluation window per IP"
  type        = number
  default     = 500
}

variable "enable_rate_limit" {
  description = "Whether to enable the IP rate-limiting rule"
  type        = bool
  default     = true
}

variable "enable_common_rule_set" {
  description = "Whether to enable the AWS Managed Common Rule Set (OWASP Top 10 mitigation)"
  type        = bool
  default     = true
}

variable "enable_known_bad_inputs_rule_set" {
  description = "Whether to enable the AWS Managed Known Bad Inputs Rule Set"
  type        = bool
  default     = true
}

variable "enable_ip_reputation_rule_set" {
  description = "Whether to enable the AWS Managed IP Reputation Rule Set"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
