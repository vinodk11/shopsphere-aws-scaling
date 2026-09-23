# ==============================================================================
# ShopSphere Stage 6: Edge Content Delivery & Perimeter Security (CloudFront + WAF)
# Discovers Stage 3 Application Load Balancer (Origin)
# Provisions ONLY the AWS WAFv2 Web ACL and Amazon CloudFront Distribution
# Keeps Stages 1-5 completely persistent with ZERO resources destroyed!
# ==============================================================================

locals {
  alb_dns_name = var.alb_dns_name != "" ? var.alb_dns_name : (
    var.alb_arn != "" ? data.aws_lb.alb[0].dns_name : data.aws_lb.alb_by_tag[0].dns_name
  )

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 6 - CloudFront + AWS WAFv2 Edge CDN and Security"
  }
}

# ------------------------------------------------------------------------------
# Module 1: AWS WAF v2 Web ACL (Edge Security Perimeter in us-east-1)
# ------------------------------------------------------------------------------
module "waf" {
  source = "./modules/waf"
  providers = {
    aws = aws.us_east_1
  }

  project_name                     = var.project_name
  environment                      = var.environment
  rate_limit                       = var.waf_rate_limit
  enable_rate_limit                = var.waf_enable_rate_limit
  enable_common_rule_set           = var.waf_enable_common_rule_set
  enable_known_bad_inputs_rule_set = var.waf_enable_known_bad_inputs_rule_set
  enable_ip_reputation_rule_set    = var.waf_enable_ip_reputation_rule_set
  tags                             = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 2: Amazon CloudFront Distribution (Global Edge Content Delivery Network)
# ------------------------------------------------------------------------------
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name        = var.project_name
  environment         = var.environment
  alb_dns_name        = local.alb_dns_name
  custom_header_name  = var.cloudfront_custom_header_name
  custom_header_value = var.cloudfront_custom_header_secret
  web_acl_arn         = module.waf.web_acl_arn
  price_class         = var.cloudfront_price_class
  tags                = local.common_tags
}
