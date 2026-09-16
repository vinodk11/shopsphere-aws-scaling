# ==============================================================================
# Amazon CloudFront Module — Stage 6 Global Edge CDN
# Accelerates static UI assets, proxies dynamic API traffic, and enforces edge security
# ==============================================================================

locals {
  origin_id = "shopsphere-alb-origin"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "ShopSphere Global Edge CDN - Stage 8 (${var.environment})"
  price_class     = var.price_class
  web_acl_id      = var.web_acl_arn

  # ----------------------------------------------------------------------------
  # Origin Configuration (Application Load Balancer)
  # ----------------------------------------------------------------------------
  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Secret origin validation header to prevent clients bypassing CloudFront / WAF
    custom_header {
      name  = var.custom_header_name
      value = var.custom_header_value
    }
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior: Static Assets (HTML, CSS, JS, Images)
  # Caches responses at edge locations to reduce ALB and EC2 compute load
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = true

      # Forward geo-location and client headers to backend for edge visualizer
      headers = [
        "Host",
        "CloudFront-Viewer-Country",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Is-Tablet-Viewer",
        "CloudFront-Is-Desktop-Viewer"
      ]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day cache for static assets
    max_ttl     = 31536000 # 1 year max cache
  }

  # ----------------------------------------------------------------------------
  # Ordered Cache Behavior 1: Dynamic APIs (/api/*)
  # Caching is disabled (TTL = 0) so checkout, inventory, and orders are never stale
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = local.origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"] # Forward all request headers to dynamic API backend

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # ----------------------------------------------------------------------------
  # Ordered Cache Behavior 2: Health Checks (/health)
  # Caching is disabled to ensure accurate health probing
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/health"
    target_origin_id       = local.origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false

    forwarded_values {
      query_string = false
      headers      = ["Host"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cdn"
      Tier = "Edge-CDN"
    }
  )
}
