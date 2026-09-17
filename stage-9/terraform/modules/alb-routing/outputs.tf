output "stage9_monolith_target_group_arn" {
  description = "ARN of the Stage 9 EKS Monolith Target Group"
  value       = aws_lb_target_group.stage9_monolith.arn
}

output "stage9_product_target_group_arn" {
  description = "ARN of the Stage 9 Product Service Target Group"
  value       = aws_lb_target_group.stage9_product.arn
}

output "stage9_order_target_group_arn" {
  description = "ARN of the Stage 9 Order Service Target Group"
  value       = aws_lb_target_group.stage9_order.arn
}

output "blue_green_listener_rule_arn" {
  description = "ARN of the Blue/Green weighted listener rule"
  value       = length(aws_lb_listener_rule.blue_green_weighted) > 0 ? aws_lb_listener_rule.blue_green_weighted[0].arn : ""
}

output "product_path_listener_rule_arn" {
  description = "ARN of the Product path-based listener rule"
  value       = length(aws_lb_listener_rule.product_service) > 0 ? aws_lb_listener_rule.product_service[0].arn : ""
}

output "order_path_listener_rule_arn" {
  description = "ARN of the Order path-based listener rule"
  value       = length(aws_lb_listener_rule.order_service) > 0 ? aws_lb_listener_rule.order_service[0].arn : ""
}
