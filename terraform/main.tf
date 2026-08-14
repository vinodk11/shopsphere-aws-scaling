locals {
  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "1"
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_name     = var.project_name
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  subnet_cidr      = var.subnet_cidr
  availability_zone = var.availability_zone
  common_tags      = local.common_tags
}

module "security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  admin_cidr   = length(var.admin_cidr) > 0 ? var.admin_cidr : [module.vpc.vpc_cidr]
  common_tags  = local.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  project_name  = var.project_name
  environment   = var.environment
  ami_id        = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id
  security_group_id = module.security_group.security_group_id
  key_name      = var.key_name

  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  app_repo_url = var.app_repo_url
  app_branch   = var.app_branch

  db_username = var.db_username
  db_password = var.db_password
  jwt_secret  = var.jwt_secret

  app_port = var.app_port
  reverse_proxy_port = var.reverse_proxy_port

  common_tags = local.common_tags
}
