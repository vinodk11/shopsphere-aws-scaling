# ==============================================================================
# Global & Environment Variables — Stage 6 (CloudFront + AWS WAFv2)
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region to deploy ShopSphere resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "The deployment environment stage"
  type        = string
  default     = "stage6"
}

# ------------------------------------------------------------------------------
# Discovery & Override Inputs from Stage 3
# ------------------------------------------------------------------------------

variable "alb_arn" {
  description = "Optional ARN of the Application Load Balancer from Stage 3"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "Optional DNS name of the Application Load Balancer from Stage 3"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# AWS WAF v2 Perimeter Security Variables
# ------------------------------------------------------------------------------

variable "waf_rate_limit" {
  description = "Maximum number of allowed requests per 5-minute rolling window per IP"
  type        = number
  default     = 2000
}

variable "waf_enable_rate_limit" {
  description = "Enable rate-limiting rule to mitigate DDoS and brute-force attacks"
  type        = bool
  default     = true
}

variable "waf_enable_common_rule_set" {
  description = "Enable AWS Managed Rules Common Rule Set (OWASP Top 10 mitigation)"
  type        = bool
  default     = true
}

variable "waf_enable_known_bad_inputs_rule_set" {
  description = "Enable AWS Managed Rules Known Bad Inputs Rule Set"
  type        = bool
  default     = true
}

variable "waf_enable_ip_reputation_rule_set" {
  description = "Enable AWS Managed Rules Amazon IP Reputation List"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Amazon CloudFront Edge CDN Variables
# ------------------------------------------------------------------------------

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class tier"
  type        = string
  default     = "PriceClass_100" # North America and Europe
}

variable "cloudfront_custom_header_name" {
  description = "Custom origin verification header name"
  type        = string
  default     = "X-ShopSphere-Origin-Verify"
}

variable "cloudfront_custom_header_secret" {
  description = "Shared secret sent from CloudFront to origin"
  type        = string
  default     = "ShopSphereEdgeSecurityToken2026!"
  sensitive   = true
}
