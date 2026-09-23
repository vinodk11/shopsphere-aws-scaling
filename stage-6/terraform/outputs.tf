# ==============================================================================
# Outputs — Stage 6 (CloudFront Edge CDN + AWS WAFv2)
# ==============================================================================

# ------------------------------------------------------------------------------
# Edge CDN & Perimeter Security Outputs (Stage 6)
# ------------------------------------------------------------------------------

output "cloudfront_url" {
  description = "Primary HTTPS URL to access ShopSphere globally via Amazon CloudFront"
  value       = module.cloudfront.cloudfront_url
}

output "cloudfront_domain_name" {
  description = "Domain name of the Amazon CloudFront CDN distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "Identifier of the Amazon CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "waf_web_acl_name" {
  description = "Name of the AWS WAF v2 Web ACL protecting CloudFront"
  value       = module.waf.web_acl_name
}

output "waf_web_acl_arn" {
  description = "ARN of the AWS WAF v2 Web ACL protecting CloudFront"
  value       = module.waf.web_acl_arn
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer (Origin)"
  value       = local.alb_dns_name
}
