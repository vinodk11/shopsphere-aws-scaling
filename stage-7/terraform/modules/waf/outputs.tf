# ==============================================================================
# AWS WAF v2 Module Outputs — Stage 6
# ==============================================================================

output "web_acl_id" {
  description = "The ID of the WAFv2 Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "The ARN of the WAFv2 Web ACL (used by CloudFront)"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "The name of the WAFv2 Web ACL"
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_capacity" {
  description = "The Web ACL capacity units (WCU) consumed by the rules"
  value       = aws_wafv2_web_acl.this.capacity
}
