# ==============================================================================
# Data Sources - Stage 2 (Decoupled Amazon RDS)
# Discovers persistent resources created in Stage 1 with ZERO re-creation
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

# 2. Discover Stage 1 Multi-AZ Private Database Subnets
data "aws_subnets" "private_db" {
  count = length(var.private_subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Tier"
    values = ["Private-Database"]
  }
}

# Fallback: if private subnets don't have tag:Tier, query non-public subnets in VPC
data "aws_subnets" "all_subnets" {
  count = length(var.private_subnet_ids) == 0 && length(try(data.aws_subnets.private_db[0].ids, [])) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# 3. Discover Stage 1 EC2 Security Group (to authorize RDS inbound access)
data "aws_security_group" "ec2" {
  count = var.ec2_security_group_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-stage1-ec2-sg"]
  }
}

# 4. Discover Running Stage 1 EC2 Instance (for outputs and migration commands)
data "aws_instances" "stage1_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-ec2"]
  }
  instance_state_names = ["running", "pending"]
}
