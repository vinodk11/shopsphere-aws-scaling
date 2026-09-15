# ==============================================================================
# AWS WAF v2 Module — Stage 6 Global Edge Perimeter Security
# Protects CloudFront distribution against OWASP Top 10, bots, and HTTP floods
# Scope: CLOUDFRONT (must reside in us-east-1)
# ==============================================================================

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.project_name}-${var.environment}-web-acl"
  description = "AWS WAF Web ACL for ShopSphere CloudFront Distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ----------------------------------------------------------------------------
  # Rule 1: AWS Managed Common Rule Set (OWASP Top 10 Mitigation)
  # ----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_common_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 10

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Rule 2: AWS Managed Known Bad Inputs Rule Set (SSRF, Malformed Requests)
  # ----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_known_bad_inputs_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 20

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-bad-inputs-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Rule 3: AWS Managed Amazon IP Reputation List (Scanners & Malicious Hosts)
  # ----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_ip_reputation_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 30

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-ip-reputation-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Rule 4: Rate-Based Rule (DDoS & Brute Force Prevention)
  # ----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_rate_limit ? [1] : []
    content {
      name     = "RateLimitPerIP"
      priority = 40

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-web-acl"
      Tier = "Security-WAF"
    }
  )
}
