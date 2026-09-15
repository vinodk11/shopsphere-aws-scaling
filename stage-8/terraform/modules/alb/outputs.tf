# ==============================================================================
# ALB Module Outputs - Stage 4
# ==============================================================================

output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.this.zone_id
}

output "target_group_id" {
  description = "The ID of the ALB target group"
  value       = aws_lb_target_group.this.id
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = aws_lb_target_group.this.arn
}

output "listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "alb_url" {
  description = "The HTTP URL to access the Application Load Balancer"
  value       = "http://${aws_lb.this.dns_name}"
}

