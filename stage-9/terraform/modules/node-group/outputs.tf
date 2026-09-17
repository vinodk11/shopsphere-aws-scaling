output "node_group_id" {
  description = "EKS Node Group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "EKS Node Group ARN"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = aws_eks_node_group.this.status
}

output "node_role_arn" {
  description = "IAM Role ARN for the worker nodes"
  value       = aws_iam_role.node.arn
}

output "node_security_group_id" {
  description = "Security Group ID of the worker nodes"
  value       = aws_security_group.node.id
}
