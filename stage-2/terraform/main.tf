# ==============================================================================
# ShopSphere Stage 2: EC2 Compute + Amazon RDS PostgreSQL (Decoupled Database)
# Discovers persistent Stage 1 VPC & Subnets; Provisions ONLY the RDS Database Tier
# Keeps Stage 1 VPC & EC2 completely untouched with ZERO resources destroyed!
# ==============================================================================

locals {
  # 1. Resolve VPC from Stage 1
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.stage1[0].id

  # 2. Resolve Private Database Subnets from Stage 1
  private_db_subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : (
    length(try(data.aws_subnets.private_db[0].ids, [])) > 0 ? data.aws_subnets.private_db[0].ids : data.aws_subnets.all_subnets[0].ids
  )

  # 3. Resolve EC2 Security Group from Stage 1
  ec2_sg_id = var.ec2_security_group_id != "" ? var.ec2_security_group_id : data.aws_security_group.ec2[0].id

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 2 - Decoupled Amazon RDS PostgreSQL"
  }
}

# ------------------------------------------------------------------------------
# 1. Amazon RDS PostgreSQL Security Group
# Strictly permits inbound port 5432 ingress only from the Stage 1 EC2 instance
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for ShopSphere Amazon RDS PostgreSQL database"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow PostgreSQL access strictly from Stage 1 EC2 application tier"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [local.ec2_sg_id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
      Tier = "Private-Database"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. Amazon RDS Managed PostgreSQL Database (Private Subnets)
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = local.private_db_subnet_ids
  rds_security_group_id   = aws_security_group.rds.id
  db_name                 = var.db_name
  db_user                 = var.db_user
  db_password             = var.db_password
  db_port                 = var.db_port
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  tags                    = local.common_tags
}
