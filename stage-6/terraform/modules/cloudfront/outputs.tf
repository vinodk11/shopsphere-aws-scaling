# ==============================================================================
# Amazon CloudFront Module Outputs — Stage 6
# ==============================================================================

output "distribution_id" {
  description = "The identifier for the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "The domain name corresponding to the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID that can be used to route an Alias resource"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "distribution_status" {
  description = "The current status of the distribution (InProgress or Deployed)"
  value       = aws_cloudfront_distribution.this.status
}

output "cloudfront_url" {
  description = "The HTTPS entrypoint URL for ShopSphere through CloudFront"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}
