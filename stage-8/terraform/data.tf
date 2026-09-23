# ==============================================================================
# Data Sources — Stage 8 (Amazon ECR Container Registry & Edge Delivery)
# Discovers persistent Stage 1-7 infrastructure with ZERO re-creation or destruction
# ==============================================================================

# Query available Availability Zones in the selected AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Discover Stage 1 VPC
data "aws_vpc" "stage1" {
  count = var.vpc_id == "" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-vpc"]
  }
}

# 2. Discover Stage 3 ALB
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

# 3. Discover Stage 3 Target Group
data "aws_lb_target_group" "tg" {
  count = var.target_group_arn != "" ? 1 : 0
  arn   = var.target_group_arn
}

data "aws_lb_target_group" "tg_by_tag" {
  count = var.target_group_arn == "" ? 1 : 0
  tags = {
    Tier = "Compute-TargetGroup"
  }
}

# 4. Discover Stage 3 ASG EC2 IAM Role
data "aws_iam_role" "asg_ec2" {
  count = var.ec2_role_name != "" ? 1 : 0
  name  = var.ec2_role_name
}
