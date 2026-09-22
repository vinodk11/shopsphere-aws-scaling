# ==============================================================================
# Outputs — Stage 10 (GitOps & Argo CD on Amazon EKS)
# ==============================================================================

output "eks_cluster_name" {
  description = "Name of the Amazon EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL for Amazon EKS control plane API"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "ARN of the Amazon EKS cluster"
  value       = module.eks.cluster_arn
}

output "eks_kubeconfig_command" {
  description = "AWS CLI command to update local kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "eks_node_group_arn" {
  description = "ARN of the EKS managed node group"
  value       = module.node_group.node_group_arn
}

output "eks_node_group_status" {
  description = "Current operational status of the EKS managed node group"
  value       = module.node_group.node_group_status
}

output "ecr_frontend_repository_url" {
  description = "ECR Repository URL for Frontend Service"
  value       = module.ecr.frontend_repository_url
}

output "ecr_product_repository_url" {
  description = "ECR Repository URL for Product Microservice"
  value       = module.ecr.product_repository_url
}

output "ecr_order_repository_url" {
  description = "ECR Repository URL for Order Microservice"
  value       = module.ecr.order_repository_url
}

output "ecr_user_repository_url" {
  description = "ECR Repository URL for User Microservice"
  value       = module.ecr.user_repository_url
}

output "stage9_frontend_target_group_arn" {
  description = "ARN of the Frontend Target Group"
  value       = module.alb_routing.stage9_frontend_target_group_arn
}

output "stage9_monolith_target_group_arn" {
  description = "ARN of the Frontend Target Group"
  value       = module.alb_routing.stage9_monolith_target_group_arn
}

output "stage9_product_target_group_arn" {
  description = "ARN of the Product Service Target Group"
  value       = module.alb_routing.stage9_product_target_group_arn
}

output "stage9_order_target_group_arn" {
  description = "ARN of the Order Service Target Group"
  value       = module.alb_routing.stage9_order_target_group_arn
}

output "stage9_user_target_group_arn" {
  description = "ARN of the User Service Target Group"
  value       = module.alb_routing.stage9_user_target_group_arn
}

output "blue_green_listener_rule_arn" {
  description = "ARN of the ALB listener rule managing Blue/Green weighted traffic"
  value       = module.alb_routing.blue_green_listener_rule_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller"
  value       = module.iam.aws_load_balancer_controller_role_arn
}

output "order_service_sqs_role_arn" {
  description = "IRSA role ARN for Order Service SQS access"
  value       = module.iam.order_service_sqs_role_arn
}

output "sqs_queue_url" {
  description = "Existing Stage 8 SQS queue URL"
  value       = data.aws_sqs_queue.orders[0].url
}

output "db_host" {
  value = var.db_host
}

output "redis_host" {
  value = var.redis_host
}

output "db_name" {
  value = var.db_name
}

output "db_user" {
  value = var.db_user
}

output "vpc_id" {
  description = "VPC ID where EKS is deployed"
  value       = local.vpc_id
}

# ------------------------------------------------------------------------------
# Argo CD Specific Outputs
# ------------------------------------------------------------------------------
output "argocd_namespace" {
  description = "Kubernetes namespace for Argo CD"
  value       = module.argocd.argocd_namespace
}

output "argocd_application_name" {
  description = "Name of the GitOps Application managed by Argo CD"
  value       = module.argocd.argocd_application_name
}

output "argocd_initial_admin_password_command" {
  description = "Command to retrieve Argo CD initial admin secret"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
}

output "argocd_port_forward_command" {
  description = "Command to expose Argo CD Web UI locally"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}
