# ==============================================================================
# Amazon CloudFront Module Variables — Stage 6
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment (e.g., stage6, dev, prod)"
  type        = string
  default     = "stage8"
}

variable "alb_dns_name" {
  description = "Public DNS hostname of the Application Load Balancer (Origin)"
  type        = string
}

variable "custom_header_name" {
  description = "Name of the custom secret verification header passed from CloudFront to ALB"
  type        = string
  default     = "X-Origin-Verify"
}

variable "custom_header_value" {
  description = "Secret token value passed from CloudFront to ALB to prevent bypassing WAF"
  type        = string
  sensitive   = true
}

variable "web_acl_arn" {
  description = "ARN of the AWS WAFv2 Web ACL to associate with CloudFront"
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront distribution price class (PriceClass_100 = North America & Europe, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "viewer_protocol_policy" {
  description = "Protocol policy for viewers (redirect-to-https, https-only, allow-all)"
  type        = string
  default     = "redirect-to-https"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
