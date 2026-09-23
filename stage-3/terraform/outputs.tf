# ==============================================================================
# ShopSphere Infrastructure Outputs (Stage 3 - ALB + ASG + Amazon RDS)
# ==============================================================================

# ------------------------------------------------------------------------------
# Discovered Foundation Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the persistent ShopSphere VPC discovered from Stage 1"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs hosting the ALB and EC2 ASG instances"
  value       = local.public_subnet_ids
}

output "rds_endpoint" {
  description = "The Amazon RDS endpoint used by the ASG compute fleet"
  value       = local.db_host
}

# ------------------------------------------------------------------------------
# Security Group Outputs (Stage 3)
# ------------------------------------------------------------------------------

output "alb_security_group_id" {
  description = "The ID of the Application Load Balancer Security Group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 Auto Scaling Group Security Group"
  value       = aws_security_group.ec2.id
}

# ------------------------------------------------------------------------------
# Application Load Balancer Outputs
# ------------------------------------------------------------------------------

output "alb_dns_name" {
  description = "The public DNS hostname of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = module.alb.target_group_arn
}

output "application_url" {
  description = "The public web entry point for ShopSphere through the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "The URL for health checks across the balanced instance fleet"
  value       = "http://${module.alb.alb_dns_name}/health"
}

output "instance_info_url" {
  description = "The URL returning JSON metadata for the serving EC2 instance (useful for verifying load balancing)"
  value       = "http://${module.alb.alb_dns_name}/api/instance-info"
}

# ------------------------------------------------------------------------------
# Auto Scaling Group Outputs
# ------------------------------------------------------------------------------

output "asg_name" {
  description = "The name of the EC2 Auto Scaling Group"
  value       = module.asg.asg_name
}

output "asg_id" {
  description = "The ID of the EC2 Auto Scaling Group"
  value       = module.asg.asg_id
}

output "asg_desired_capacity" {
  description = "The desired number of running EC2 instances in the ASG"
  value       = module.asg.desired_capacity
}

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template powering the ASG"
  value       = module.asg.launch_template_id
}

# ------------------------------------------------------------------------------
# Verification Helper Command
# ------------------------------------------------------------------------------

output "load_balancer_test_command" {
  description = "Bash command to verify round-robin traffic distribution across ASG instances"
  value       = "for i in {1..10}; do curl -s http://${module.alb.alb_dns_name}/api/instance-info | grep -o '\"hostname\":\"[^\"]*\"'; sleep 0.3; done"
}
