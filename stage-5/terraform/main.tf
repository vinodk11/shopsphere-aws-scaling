# ==============================================================================
# ShopSphere Stage 5: ALB + ASG + ElastiCache Redis + Amazon RDS + SQS + Lambda
# Decoupled Asynchronous Order Processing Architecture
# ==============================================================================

locals {
  # Resolve AZs dynamically (requires at least 2 AZs for ALB, RDS, and ElastiCache)
  selected_azs = coalesce(
    var.availability_zones,
    slice(data.aws_availability_zones.available.names, 0, 2)
  )

  public_azs  = local.selected_azs
  private_azs = local.selected_azs

  # Resolve AMI dynamically if not explicitly overridden
  ami_id = coalesce(var.custom_ami_id, data.aws_ami.amazon_linux_2023.id)

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 5 - SQS + AWS Lambda + ElastiCache Redis + RDS + ALB + ASG"
  }
}

# ------------------------------------------------------------------------------
# Module 1: Multi-AZ Multi-Tier VPC Networking
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  public_subnet_cidrs        = var.public_subnet_cidrs
  public_availability_zones  = local.public_azs
  private_db_subnet_cidrs    = var.private_db_subnet_cidrs
  private_cache_subnet_cidrs = var.private_cache_subnet_cidrs
  private_availability_zones = local.private_azs
  tags                       = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 2: Tiered Security Group Firewalls (ALB, EC2 ASG, RDS, ElastiCache)
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
# Module 4: Amazon RDS Managed PostgreSQL Database (Private DB Subnets)
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = module.vpc.private_db_subnet_ids
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
# Module 5: Amazon ElastiCache Redis Cluster (Private Cache Subnets)
# ------------------------------------------------------------------------------
module "elasticache" {
  source = "./modules/elasticache"

  project_name                  = var.project_name
  environment                   = var.environment
  cache_subnet_ids              = module.vpc.private_cache_subnet_ids
  elasticache_security_group_id = module.security_group.elasticache_security_group_id
  cache_node_type               = var.cache_node_type
  redis_engine_version          = var.redis_engine_version
  redis_port                    = var.redis_port
  tags                          = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 6: Amazon SQS Message Queues (Main Queue + DLQ + Redrive Policy)
# ------------------------------------------------------------------------------
module "sqs" {
  source = "./modules/sqs"

  project_name               = var.project_name
  environment                = var.environment
  queue_name                 = var.sqs_queue_name
  dlq_name                   = var.sqs_dlq_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  max_receive_count          = var.sqs_max_receive_count
  sqs_managed_sse_enabled    = var.sqs_managed_sse_enabled
  tags                       = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 7: IAM Roles & Policies (EC2 Publisher & Lambda Consumer)
# ------------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  sqs_queue_arn = module.sqs.queue_arn
  tags          = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 8: AWS Lambda Serverless Worker & SQS Event Source Mapping
# ------------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  project_name                       = var.project_name
  environment                        = var.environment
  function_name                      = var.lambda_function_name
  lambda_role_arn                    = module.iam.lambda_role_arn
  source_dir                         = "${path.module}/../lambda"
  handler                            = "index.handler"
  runtime                            = var.lambda_runtime
  timeout                            = var.lambda_timeout
  memory_size                        = var.lambda_memory_size
  sqs_queue_arn                      = module.sqs.queue_arn
  batch_size                         = var.lambda_batch_size
  maximum_batching_window_in_seconds = var.lambda_maximum_batching_window_in_seconds
  log_retention_in_days              = var.lambda_log_retention_in_days

  environment_variables = {
    ENVIRONMENT                 = var.environment
    STAGE                       = "stage-5"
    LOG_LEVEL                   = "info"
    SIMULATE_PROCESSING_TIME_MS = "80"
    DB_HOST                     = module.rds.db_instance_address
    DB_PORT                     = tostring(module.rds.db_instance_port)
    DB_NAME                     = var.db_name
    DB_USER                     = var.db_user
    DB_PASSWORD                 = var.db_password
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Module 9: Auto Scaling Group & Launch Template (Horizontal Scaling EC2 Fleet)
# ------------------------------------------------------------------------------
module "asg" {
  source = "./modules/asg"

  # Explicit dependencies ensure RDS, Redis, and SQS are available before EC2 launches
  depends_on = [module.rds, module.elasticache, module.sqs]

  project_name              = var.project_name
  environment               = var.environment
  ami_id                    = local.ami_id
  instance_type             = var.instance_type
  key_name                  = var.ssh_key_name
  security_group_id         = module.security_group.ec2_security_group_id
  subnet_ids                = module.vpc.public_subnet_ids
  target_group_arn          = module.alb.target_group_arn
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  target_cpu_utilization    = var.asg_target_cpu_utilization
  root_volume_size          = var.root_volume_size

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    db_host        = module.rds.db_instance_address
    db_port        = module.rds.db_instance_port
    db_name        = var.db_name
    db_user        = var.db_user
    db_password    = var.db_password
    redis_host     = module.elasticache.redis_endpoint
    redis_port     = module.elasticache.redis_port
    aws_region     = var.aws_region
    sqs_queue_url  = module.sqs.queue_url
    sqs_queue_name = module.sqs.queue_name
    app_port       = var.app_port
    app_repo_url   = var.app_repo_url
  })

  tags = local.common_tags
}
