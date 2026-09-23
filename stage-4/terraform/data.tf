# ==============================================================================
# Data Sources - Stage 4 (Amazon ElastiCache Redis In-Memory Caching)
# Discovers persistent Stage 1 Networking, Stage 2 RDS, and Stage 3 ASG/ALB
# with ZERO re-creation or destruction
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

# 2. Discover Stage 1 Private Cache Subnets across Multi-AZ
data "aws_subnets" "cache" {
  count = length(var.cache_subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Tier"
    values = ["Private-Cache"]
  }
}

# 3. Discover Stage 3 EC2 ASG Security Group
data "aws_security_group" "asg" {
  count = var.asg_security_group_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-ec2-sg"]
  }
}

# 4. Discover Stage 3 ALB (for DNS name and health/cache testing)
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
