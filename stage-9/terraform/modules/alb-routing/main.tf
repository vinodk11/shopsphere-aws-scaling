# Stage 9 reuses the existing Stage 8 ALB.
# Terraform owns the listener rules and target groups; AWS Load Balancer Controller
# owns registration of Kubernetes Service endpoints into these existing target groups.

locals {
  path_priority_product = 5
  path_priority_order   = 6
  path_priority_user    = 7
  blue_green_priority   = 9
}

resource "aws_lb_target_group" "stage9_monolith" {
  name        = "${var.project_name}-${var.environment}-eks-mono-tg"
  port        = 30080
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

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-eks-mono-tg"
    Service     = "monolith"
    Stage       = "Stage-9"
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "stage9_product" {
  name        = "${var.project_name}-${var.environment}-eks-prod-tg"
  port        = 30081
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

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-eks-prod-tg"
    Service     = "product"
    Stage       = "Stage-9"
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "stage9_order" {
  name        = "${var.project_name}-${var.environment}-eks-ord-tg"
  port        = 30082
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

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-eks-ord-tg"
    Service     = "order"
    Stage       = "Stage-9"
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "stage9_user" {
  name        = "${var.project_name}-${var.environment}-eks-user-tg"
  port        = 30083
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

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-eks-user-tg"
    Service     = "user"
    Stage       = "Stage-9"
    Environment = var.environment
  })
}

# Lower priority number = evaluated first by ALB. These rules must be before /*.
resource "aws_lb_listener_rule" "product_service" {
  count        = var.enable_product_path_routing ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = local.path_priority_product

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage9_product.arn
  }

  condition {
    path_pattern { values = ["/api/products", "/api/products/*"] }
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
}

resource "aws_lb_listener_rule" "order_service" {
  count        = var.enable_order_path_routing ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = local.path_priority_order

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage9_order.arn
  }

  condition {
    path_pattern { values = ["/api/orders", "/api/orders/*"] }
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
}

resource "aws_lb_listener_rule" "user_service" {
  count        = var.enable_user_path_routing ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = local.path_priority_user

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage9_user.arn
  }

  condition {
    path_pattern { values = ["/api/users", "/api/users/*"] }
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
}

# Catch-all for the migration. Path rules above take precedence.
resource "aws_lb_listener_rule" "blue_green_weighted" {
  count        = var.enable_blue_green_weighted ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = local.blue_green_priority

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

  condition { path_pattern { values = ["/*"] } }

  dynamic "condition" {
    for_each = var.custom_header_name != "" && var.custom_header_value != "" ? [1] : []
    content {
      http_header {
        http_header_name = var.custom_header_name
        values           = [var.custom_header_value]
      }
    }
  }
}
