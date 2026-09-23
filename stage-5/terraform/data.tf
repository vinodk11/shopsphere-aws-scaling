# ==============================================================================
# Data Sources — Stage 5 (Amazon SQS + AWS Lambda Asynchronous Order Processing)
# Discovers persistent Stage 1-4 infrastructure with ZERO re-creation or destruction
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

# 2. Discover Stage 2 Amazon RDS PostgreSQL Database (Optional for Lambda Worker)
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

# 3. Discover Stage 3 EC2 ASG IAM Role (for SQS publisher policy attachment)
data "aws_iam_role" "asg_ec2" {
  count = var.ec2_role_name != "" ? 1 : 0
  name  = var.ec2_role_name
}

# 4. Discover Stage 3 ALB (for DNS name and API order testing)
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
