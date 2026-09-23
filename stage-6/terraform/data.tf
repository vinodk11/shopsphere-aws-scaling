# ==============================================================================
# Data Sources — Stage 6 (CloudFront Edge CDN + AWS WAFv2 Security)
# Discovers persistent Stage 3 ALB with ZERO re-creation or destruction
# ==============================================================================

# 1. Discover Stage 3 ALB
data "aws_lb" "alb" {
  count = var.alb_arn != "" ? 1 : 0
  arn   = var.alb_arn
}

data "aws_lb" "alb_by_tag" {
  count = var.alb_arn == "" ? 1 : 0
  tags = {
    Tier = "Public-ALB"
  }
}
