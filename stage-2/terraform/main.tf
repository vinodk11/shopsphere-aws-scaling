# ==============================================================================
# ShopSphere Stage 2: EC2 Compute + Amazon RDS PostgreSQL (Decoupled Database)
# ==============================================================================

locals {
  # Resolve AZs dynamically if not explicitly specified (requires at least 2 for RDS DB Subnet Group)
  selected_azs = coalesce(
    var.availability_zones,
    slice(data.aws_availability_zones.available.names, 0, 2)
  )

  # Public subnet AZ (uses first AZ)
  public_az = local.selected_azs[0]

  # Private subnet AZs (spans both AZs)
  private_azs = local.selected_azs

  # Resolve AMI dynamically if not explicitly overridden
  ami_id = coalesce(var.custom_ami_id, data.aws_ami.amazon_linux_2023.id)

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 2 - EC2 + Amazon RDS Decoupled Database"
  }
}

# ------------------------------------------------------------------------------
# Module 1: Dedicated Multi-Tier VPC Networking
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  public_subnet_cidr         = var.public_subnet_cidr
  public_availability_zone   = local.public_az
  private_subnet_cidrs       = var.private_subnet_cidrs
  private_availability_zones = local.private_azs
  tags                       = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 2: Security Group Firewalls (EC2 Tier & RDS Tier)
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
# Module 3: Amazon RDS Managed PostgreSQL Database (Private Subnets)
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
# Module 4: EC2 Compute Server with User Data Bootstrap
# ------------------------------------------------------------------------------
module "ec2" {
  source = "./modules/ec2"

  # Explicit dependency ensures RDS is provisioned and ready before EC2 bootstraps
  depends_on = [module.rds]

  project_name      = var.project_name
  environment       = var.environment
  ami_id            = local.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security_group.ec2_security_group_id
  key_name          = var.ssh_key_name
  root_volume_size  = var.root_volume_size

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
