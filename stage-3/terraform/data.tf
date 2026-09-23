# ==============================================================================
# Data Sources - Stage 3 (ALB + ASG Multi-AZ Scale)
# Discovers persistent Stage 1 Networking & Stage 2 RDS Database with ZERO re-creation
# ==============================================================================

# Query available Availability Zones in the selected AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# Dynamically lookup the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 1. Discover Stage 1 VPC
data "aws_vpc" "stage1" {
  count = var.vpc_id == "" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-vpc"]
  }
}

# 2. Discover Stage 1 Public Subnets across Multi-AZ
data "aws_subnets" "public" {
  count = length(var.public_subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Tier"
    values = ["Public"]
  }
}

# 3. Discover Stage 2 Amazon RDS PostgreSQL Database
data "aws_db_instances" "stage2_rds" {
  filter {
    name   = "db-instance-id"
    values = ["${var.project_name}-*-postgres"]
  }
}

data "aws_db_instance" "stage2_rds" {
  count                  = var.db_host == "" && length(try(data.aws_db_instances.stage2_rds.instance_identifiers, [])) > 0 ? 1 : 0
  db_instance_identifier = data.aws_db_instances.stage2_rds.instance_identifiers[0]
}

# 4. Discover Stage 2 RDS Security Group
data "aws_security_group" "rds" {
  count = var.rds_security_group_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-rds-sg"]
  }
}
