# ==============================================================================
# ShopSphere Stage 3: ALB + Auto Scaling Group + Multi-EC2 + Amazon RDS
# ==============================================================================

locals {
  # Resolve AZs dynamically if not explicitly specified (requires at least 2 AZs for ALB and RDS)
  selected_azs = coalesce(
    var.availability_zones,
    slice(data.aws_availability_zones.available.names, 0, 2)
  )

  # Public subnets span across at least 2 AZs
  public_azs = local.selected_azs

  # Private subnets span across at least 2 AZs
  private_azs = local.selected_azs

  # Resolve AMI dynamically if not explicitly overridden
  ami_id = coalesce(var.custom_ami_id, data.aws_ami.amazon_linux_2023.id)

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 3 - ALB + Auto Scaling Group + Multi-EC2 + Amazon RDS"
  }
}

# ------------------------------------------------------------------------------
# Module 1: Dedicated Multi-AZ VPC Networking
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  public_subnet_cidrs        = var.public_subnet_cidrs
  public_availability_zones  = local.public_azs
  private_subnet_cidrs       = var.private_subnet_cidrs
  private_availability_zones = local.private_azs
  tags                       = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 2: Tiered Security Group Firewalls (ALB, EC2 ASG, RDS)
# ------------------------------------------------------------------------------
module "security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  admin_cidr   = var.admin_cidr
  tags         = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 3: Application Load Balancer (Public Ingress & Target Group)
# ------------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_group.alb_security_group_id
  health_check_path     = "/health"
  tags                  = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 4: Amazon RDS Managed PostgreSQL Database (Private Subnets)
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = module.vpc.private_subnet_ids
  rds_security_group_id   = module.security_group.rds_security_group_id
  db_name                 = var.db_name
  db_user                 = var.db_user
  db_password             = var.db_password
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  tags                    = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 5: Auto Scaling Group & Launch Template (Horizontal Scaling EC2 Compute)
# ------------------------------------------------------------------------------
module "asg" {
  source = "./modules/asg"

  # Explicit dependency ensures RDS is ready before instances boot and attempt schema sync
  depends_on = [module.rds]

  project_name           = var.project_name
  environment            = var.environment
  ami_id                 = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  security_group_id      = module.security_group.ec2_security_group_id
  subnet_ids             = module.vpc.public_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  target_cpu_utilization = var.asg_target_cpu_utilization
  root_volume_size       = var.root_volume_size

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    db_host      = module.rds.db_instance_address
    db_port      = module.rds.db_instance_port
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = var.db_password
    app_port     = var.app_port
    app_repo_url = var.app_repo_url
  })

  tags = local.common_tags
}
