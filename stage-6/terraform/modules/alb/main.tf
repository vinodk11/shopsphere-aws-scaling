# ==============================================================================
# ALB Module - Stage 4 Application Load Balancer
# ==============================================================================

# 1. Application Load Balancer
resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
      Tier = "Public-ALB"
    }
  )
}

# 2. ALB Target Group
resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
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
      Name = "${var.project_name}-${var.environment}-tg"
      Tier = "Compute-TargetGroup"
    }
  )
}

# 3. HTTP Listener (with optional CloudFront origin header lockdown)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # If lockdown is enabled, default action rejects direct requests with 403 Forbidden
  default_action {
    type             = var.enable_header_lockdown ? "fixed-response" : "forward"
    target_group_arn = var.enable_header_lockdown ? null : aws_lb_target_group.this.arn

    dynamic "fixed_response" {
      for_each = var.enable_header_lockdown ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Access Denied: Direct requests to ALB are forbidden. Access ShopSphere via Amazon CloudFront CDN."
        status_code  = "403"
      }
    }
  }
}

# 4. Listener Rule: Forward to Target Group ONLY if CloudFront verification header matches
resource "aws_lb_listener_rule" "allow_cloudfront" {
  count        = var.enable_header_lockdown ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    http_header {
      http_header_name = var.custom_header_name
      values           = [var.custom_header_value]
    }
  }
}

