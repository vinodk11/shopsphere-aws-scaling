# ==============================================================================
# ShopSphere Stage 4: Amazon ElastiCache Redis In-Memory Caching Tier
# Discovers Stage 1 VPC & Private Cache Subnets, Stage 3 EC2 ASG Security Group
# Provisions ONLY the ElastiCache Redis Cluster & Security Group
# Keeps Stages 1, 2, and 3 completely persistent with ZERO resources destroyed!
# ==============================================================================

locals {
  # 1. Resolve VPC from Stage 1
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.stage1[0].id

  # 2. Resolve Multi-AZ Private Cache Subnets from Stage 1
  cache_subnet_ids = length(var.cache_subnet_ids) > 0 ? var.cache_subnet_ids : data.aws_subnets.cache[0].ids

  # 3. Resolve ASG Security Group ID from Stage 3
  asg_sg_id = var.asg_security_group_id != "" ? var.asg_security_group_id : data.aws_security_group.asg[0].id

  # 4. Resolve ALB DNS Name from Stage 3
  alb_dns_name = var.alb_dns_name != "" ? var.alb_dns_name : (
    var.alb_arn != "" ? try(data.aws_lb.alb[0].dns_name, "") : try(data.aws_lb.alb_by_tag[0].dns_name, "")
  )

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 4 - Amazon ElastiCache Redis In-Memory Caching"
  }
}

# ------------------------------------------------------------------------------
# 1. ElastiCache Redis Security Group (In-Memory Cache Tier)
# Ingress strictly allowed from Stage 3 ASG EC2 Security Group ONLY
# ------------------------------------------------------------------------------
resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group for ShopSphere Amazon ElastiCache Redis cluster"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow Redis access strictly from ASG compute tier"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [local.asg_sg_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-sg"
      Tier = "Private-Cache"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. Amazon ElastiCache Redis Cluster (Private Cache Subnets)
# ------------------------------------------------------------------------------
module "elasticache" {
  source = "./modules/elasticache"

  project_name                  = var.project_name
  environment                   = var.environment
  cache_subnet_ids              = local.cache_subnet_ids
  elasticache_security_group_id = aws_security_group.elasticache.id
  cache_node_type               = var.cache_node_type
  redis_engine_version          = var.redis_engine_version
  redis_port                    = var.redis_port
  tags                          = local.common_tags
}
