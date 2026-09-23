# ==============================================================================
# ShopSphere Stage 1: Single EC2 + Colocated Database
# ==============================================================================

locals {
  # Resolve AZs dynamically if not explicitly specified (requires at least 2 for future Multi-AZ tiers)
  selected_azs = coalesce(
    var.availability_zones,
    slice(data.aws_availability_zones.available.names, 0, 2)
  )

  # Resolve AMI dynamically if not explicitly overridden
  ami_id = coalesce(var.custom_ami_id, data.aws_ami.amazon_linux_2023.id)

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 1 - Single EC2 Monolith"
  }
}

# ------------------------------------------------------------------------------
# Module 1: Dedicated Multi-Tier Multi-AZ VPC Networking
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  public_subnet_cidrs        = var.public_subnet_cidrs
  private_db_subnet_cidrs    = var.private_db_subnet_cidrs
  private_cache_subnet_cidrs = var.private_cache_subnet_cidrs
  availability_zones         = local.selected_azs
  tags                       = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 2: Security Group Firewall
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
# Module 3: EC2 Single-Server Compute with User Data Bootstrap
# ------------------------------------------------------------------------------
module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  environment       = var.environment
  ami_id            = local.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security_group.security_group_id
  key_name          = var.ssh_key_name
  root_volume_size  = var.root_volume_size

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = var.db_password
    app_port     = var.app_port
    app_repo_url = var.app_repo_url
  })

  tags = local.common_tags
}
