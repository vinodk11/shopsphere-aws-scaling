# ==============================================================================
# Main Orchestration - Stage 9 (EKS Cluster & Progressive Microservices Migration)
# Integrates with existing Stage 8 infrastructure without modifying or stopping it
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Discover Existing Stage 8 Infrastructure Resources
# ------------------------------------------------------------------------------

# Discover VPC (checks stage8, then fallback to stage6)
data "aws_vpc" "stage8" {
  count = var.vpc_id == "" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-vpc"]
  }
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.stage8[0].id
}

# Discover Multi-AZ private subnets first. Explicit subnet_ids always win.
data "aws_subnets" "private" {
  count = length(var.subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Tier"
    values = ["Private"]
  }
}

data "aws_subnets" "public" {
  count = length(var.subnet_ids) == 0 && length(data.aws_subnets.private[0].ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Tier"
    values = ["Public"]
  }
}

locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (
    length(data.aws_subnets.private[0].ids) > 0 ? data.aws_subnets.private[0].ids : data.aws_subnets.public[0].ids
  )
}

# Existing ALB: support either an explicit ARN or tag-based discovery from Stage 3
data "aws_lb" "existing_by_arn" {
  count = var.alb_arn != "" ? 1 : 0
  arn   = var.alb_arn
}

data "aws_lb" "existing_by_tag" {
  count = var.alb_arn == "" ? 1 : 0
  tags = {
    Tier = "Public-ALB"
  }
}

locals {
  alb_arn = var.alb_arn != "" ? data.aws_lb.existing_by_arn[0].arn : data.aws_lb.existing_by_tag[0].arn
  alb_sg  = var.alb_arn != "" ? tolist(data.aws_lb.existing_by_arn[0].security_groups)[0] : tolist(data.aws_lb.existing_by_tag[0].security_groups)[0]
}

data "aws_lb_listener" "existing_http" {
  count             = var.alb_listener_arn == "" ? 1 : 0
  load_balancer_arn = local.alb_arn
  port              = 80
}

locals {
  alb_listener_arn = var.alb_listener_arn != "" ? var.alb_listener_arn : data.aws_lb_listener.existing_http[0].arn
}

# Existing Stage 8 / Monolith target group used as Blue (discovered via ARN or Tier tag)
data "aws_lb_target_group" "stage8_by_arn" {
  count = var.stage8_target_group_arn != "" ? 1 : 0
  arn   = var.stage8_target_group_arn
}

data "aws_lb_target_group" "stage8_by_tag" {
  count = var.stage8_target_group_arn == "" ? 1 : 0
  tags = {
    Tier = "Compute-TargetGroup"
  }
}

locals {
  stage8_tg_arn = var.stage8_target_group_arn != "" ? data.aws_lb_target_group.stage8_by_arn[0].arn : data.aws_lb_target_group.stage8_by_tag[0].arn
}

# Discover existing SQS Queue ARN from Stage 5
data "aws_sqs_queue" "orders" {
  count = var.sqs_queue_arn == "" ? 1 : 0
  name  = var.sqs_queue_name != "" ? var.sqs_queue_name : "${var.project_name}-stage5-order-processing-queue"
}

locals {
  sqs_queue_arn = var.sqs_queue_arn != "" ? var.sqs_queue_arn : (
    length(data.aws_sqs_queue.orders) > 0 ? data.aws_sqs_queue.orders[0].arn : ""
  )
}

# Discover existing RDS Security Group
data "aws_security_group" "rds" {
  count = var.rds_security_group_id == "" ? 1 : 0
  filter {
    name   = "group-name"
    values = ["${var.project_name}-*-rds-sg"]
  }
}

locals {
  rds_sg_id = var.rds_security_group_id != "" ? var.rds_security_group_id : data.aws_security_group.rds[0].id
}

# Discover existing Redis Security Group
data "aws_security_group" "redis" {
  count = var.redis_security_group_id == "" ? 1 : 0
  filter {
    name   = "group-name"
    values = ["${var.project_name}-*-redis-sg"]
  }
}

locals {
  redis_sg_id = var.redis_security_group_id != "" ? var.redis_security_group_id : data.aws_security_group.redis[0].id
}

# Discover Stage 2 RDS Endpoint dynamically if placeholder is present or db_host is empty
data "aws_db_instance" "stage2_rds" {
  count                  = (var.db_host == "" || can(regex("cy9mak0su1oj", var.db_host))) ? 1 : 0
  db_instance_identifier = var.db_instance_identifier != "" ? var.db_instance_identifier : "${var.project_name}-stage2-postgres"
}

locals {
  db_host = (var.db_host != "" && !can(regex("cy9mak0su1oj", var.db_host))) ? var.db_host : (
    length(data.aws_db_instance.stage2_rds) > 0 ? data.aws_db_instance.stage2_rds[0].address : var.db_host
  )
}

# Discover Stage 4 ElastiCache Redis Endpoint dynamically if placeholder is present
data "aws_elasticache_cluster" "stage4_redis" {
  count      = (var.redis_host == "" || can(regex("ekxmke", var.redis_host))) ? 1 : 0
  cluster_id = "${var.project_name}-stage4-redis"
}

locals {
  redis_host = (var.redis_host != "" && !can(regex("ekxmke", var.redis_host))) ? var.redis_host : (
    length(try(data.aws_elasticache_cluster.stage4_redis, [])) > 0 ? try(data.aws_elasticache_cluster.stage4_redis[0].cache_nodes[0].address, var.redis_host) : var.redis_host
  )
}

# ------------------------------------------------------------------------------
# 2. EKS Control Plane Module
# ------------------------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = local.vpc_id
  subnet_ids         = local.subnet_ids
  kubernetes_version = var.kubernetes_version
  tags               = var.tags
}

# ------------------------------------------------------------------------------
# 3. EKS Managed Multi-AZ Worker Fleet
# ------------------------------------------------------------------------------
module "node_group" {
  source = "./modules/node-group"

  project_name              = var.project_name
  environment               = var.environment
  cluster_name              = module.eks.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  vpc_id                    = local.vpc_id
  subnet_ids                = local.subnet_ids
  alb_security_group_id     = local.alb_sg
  rds_security_group_id     = local.rds_sg_id
  redis_security_group_id   = local.redis_sg_id
  instance_types            = var.instance_types
  kubernetes_version        = var.kubernetes_version
  desired_capacity          = var.desired_capacity
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  disk_size                 = var.disk_size
  tags                      = var.tags

  depends_on = [module.eks]
}

# ------------------------------------------------------------------------------
# 4. IAM Roles for Service Accounts (IRSA)
# ------------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  sqs_queue_arn     = local.sqs_queue_arn
  tags              = var.tags
}

# ------------------------------------------------------------------------------
# 5. Microservices Container Registries (Amazon ECR)
# ------------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

# ------------------------------------------------------------------------------
# 6. ALB Routing & Blue/Green Traffic Management
# ------------------------------------------------------------------------------
module "alb_routing" {
  source = "./modules/alb-routing"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = local.vpc_id
  alb_listener_arn            = local.alb_listener_arn
  stage8_target_group_arn     = local.stage8_tg_arn
  blue_weight                 = var.blue_weight
  green_weight                = var.green_weight
  enable_product_path_routing = var.enable_product_path_routing
  enable_order_path_routing   = var.enable_order_path_routing
  enable_user_path_routing    = var.enable_user_path_routing
  custom_header_name          = var.custom_header_name
  custom_header_value         = var.custom_header_value
  tags                        = var.tags
}
