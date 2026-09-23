# ==============================================================================
# ShopSphere Stage 3: ALB + Auto Scaling Group + Multi-EC2 (High Availability)
# Discovers Stage 1 VPC/Subnets & Stage 2 Amazon RDS Database
# Provisions ONLY the Load Balancing (ALB) and Elastic Scaling (ASG) Tiers
# Keeps Stage 1 and Stage 2 completely persistent with ZERO resources destroyed!
# ==============================================================================

locals {
  # 1. Resolve VPC from Stage 1
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.stage1[0].id

  # 2. Resolve Multi-AZ Public Subnets from Stage 1
  public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public[0].ids

  # 3. Resolve Stage 2 Amazon RDS Endpoint
  db_host = var.db_host != "" ? var.db_host : (
    length(try(data.aws_db_instance.stage2_rds, [])) > 0 ? data.aws_db_instance.stage2_rds[0].address : "localhost"
  )

  # 4. Resolve Stage 2 RDS Security Group ID
  rds_sg_id = var.rds_security_group_id != "" ? var.rds_security_group_id : (
    length(try(data.aws_security_group.rds, [])) > 0 ? data.aws_security_group.rds[0].id : null
  )

  # Resolve AMI dynamically if not explicitly overridden
  ami_id = coalesce(var.custom_ami_id, data.aws_ami.amazon_linux_2023.id)

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 3 - ALB + Auto Scaling Group High Availability"
  }
}

# ------------------------------------------------------------------------------
# 1. ALB Security Group (Public Edge Tier)
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ShopSphere Application Load Balancer"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow HTTP from web clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from web clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to backend compute targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Tier = "Public-ALB"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. EC2 ASG Security Group (Compute Tier)
# Ingress strictly allowed from ALB Security Group ONLY
# ------------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ShopSphere Auto Scaling Group EC2 instances"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow HTTP traffic strictly from Application Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Allow SSH from authorized administrator IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr
  }

  egress {
    description = "Allow all outbound traffic (package downloads, git cloning, RDS connectivity)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
      Tier = "Compute-ASG"
    }
  )
}

# ------------------------------------------------------------------------------
# 3. Authorize ASG Compute Fleet to access Stage 2 RDS Database
# ------------------------------------------------------------------------------
resource "aws_security_group_rule" "rds_ingress_from_asg" {
  count                    = local.rds_sg_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = local.rds_sg_id
  description              = "Allow PostgreSQL access from Stage 3 ASG compute fleet"
}

# ------------------------------------------------------------------------------
# 4. Application Load Balancer (Public Ingress & Target Group)
# ------------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = local.vpc_id
  public_subnet_ids     = local.public_subnet_ids
  alb_security_group_id = aws_security_group.alb.id
  health_check_path     = "/health"
  tags                  = local.common_tags
}

# ------------------------------------------------------------------------------
# 5. Auto Scaling Group & Launch Template (Horizontal Scaling EC2 Compute)
# ------------------------------------------------------------------------------
module "asg" {
  source = "./modules/asg"

  project_name           = var.project_name
  environment            = var.environment
  ami_id                 = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  security_group_id      = aws_security_group.ec2.id
  subnet_ids             = local.public_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  target_cpu_utilization = var.asg_target_cpu_utilization
  root_volume_size       = var.root_volume_size

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    db_host      = local.db_host
    db_port      = var.db_port
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = var.db_password
    app_port     = var.app_port
    app_repo_url = var.app_repo_url
  })

  tags = local.common_tags
}
