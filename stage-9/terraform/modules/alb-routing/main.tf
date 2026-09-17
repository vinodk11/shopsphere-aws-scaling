# ==============================================================================
# ALB Routing Module - Stage 9 Blue/Green & Path-Based Traffic Migration
# Coexists with Stage 8 ALB to enable progressive zero-downtime traffic shift
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Stage 9 General EKS Target Group (Monolith Compatibility Workload)
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "stage9_monolith" {
  name        = "${var.project_name}-${var.environment}-eks-mono-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-eks-mono-tg"
      Tier        = "Compute-TargetGroup"
      Stage       = "Stage-9"
      Environment = var.environment
    }
  )
}

# ------------------------------------------------------------------------------
# 2. Stage 9 Product Microservice Target Group
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "stage9_product" {
  name        = "${var.project_name}-${var.environment}-eks-prod-tg"
  port        = 30081 # NodePort or ALB Controller IP target
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-eks-prod-tg"
      Service     = "product"
      Stage       = "Stage-9"
      Environment = var.environment
    }
  )
}

# ------------------------------------------------------------------------------
# 3. Stage 9 Order Microservice Target Group
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "stage9_order" {
  name        = "${var.project_name}-${var.environment}-eks-ord-tg"
  port        = 30082 # NodePort or ALB Controller IP target
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-eks-ord-tg"
      Service     = "order"
      Stage       = "Stage-9"
      Environment = var.environment
    }
  )
}

# ------------------------------------------------------------------------------
# 4. Path-Based Listener Rule: Route /api/products* to Stage 9 Product Service
# (Enabled only when enable_product_path_routing = true)
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "product_service" {
  count        = var.enable_product_path_routing ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage9_product.arn
  }

  condition {
    path_pattern {
      values = ["/api/products", "/api/products/*"]
    }
  }

  # If CloudFront header verification is enabled, also enforce header condition
  dynamic "condition" {
    for_each = var.custom_header_name != "" && var.custom_header_value != "" ? [1] : []
    content {
      http_header {
        http_header_name = var.custom_header_name
        values           = [var.custom_header_value]
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-rule-product-path"
      Service = "product"
    }
  )
}

# ------------------------------------------------------------------------------
# 5. Path-Based Listener Rule: Route /api/orders* to Stage 9 Order Service
# (Enabled only when enable_order_path_routing = true)
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "order_service" {
  count        = var.enable_order_path_routing ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = 25

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage9_order.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders", "/api/orders/*"]
    }
  }

  dynamic "condition" {
    for_each = var.custom_header_name != "" && var.custom_header_value != "" ? [1] : []
    content {
      http_header {
        http_header_name = var.custom_header_name
        values           = [var.custom_header_value]
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-rule-order-path"
      Service = "order"
    }
  )
}

# ------------------------------------------------------------------------------
# 6. Blue/Green Weighted Listener Rule (Canary & Progressive Traffic Migration)
# Priority 15 (Evaluated before default Stage 8 rule)
# Blue  = Stage 8 EC2 ASG Target Group
# Green = Stage 9 EKS Monolith Target Group
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "blue_green_weighted" {
  count        = var.enable_blue_green_weighted ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = 15

  action {
    type = "forward"
    forward {
      target_group {
        arn    = var.stage8_target_group_arn
        weight = var.blue_weight
      }

      target_group {
        arn    = aws_lb_target_group.stage9_monolith.arn
        weight = var.green_weight
      }
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  # Match CloudFront custom verification header if provided
  dynamic "condition" {
    for_each = var.custom_header_name != "" && var.custom_header_value != "" ? [1] : []
    content {
      http_header {
        http_header_name = var.custom_header_name
        values           = [var.custom_header_value]
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rule-blue-green"
    }
  )
}
