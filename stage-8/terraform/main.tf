# ==============================================================================
# ShopSphere Stage 8: Containerization Tier (Amazon ECR + Docker ASG Rollout)
# Discovers persistent infrastructure from Stages 1-7
# Provisions ONLY the Amazon ECR Repository and IAM Permissions for ECR Pull
# Keeps Stages 1-7 completely persistent with ZERO resources destroyed!
# ==============================================================================

locals {
  alb_dns_name = var.alb_dns_name != "" ? var.alb_dns_name : (
    var.alb_arn != "" ? try(data.aws_lb.alb[0].dns_name, "") : try(data.aws_lb.alb_by_tag[0].dns_name, "")
  )

  target_group_arn = var.target_group_arn != "" ? var.target_group_arn : (
    var.target_group_arn != "" ? try(data.aws_lb_target_group.tg[0].arn, "") : try(data.aws_lb_target_group.tg_by_tag[0].arn, "")
  )

  asg_name = var.asg_name != "" ? var.asg_name : "${var.project_name}-stage3-asg"

  launch_template_id = var.launch_template_id

  cloudfront_domain_name = var.cloudfront_domain_name

  ec2_role_name = var.ec2_role_name != "" ? var.ec2_role_name : (
    length(try(data.aws_iam_role.asg_ec2, [])) > 0 ? data.aws_iam_role.asg_ec2[0].name : "${var.project_name}-stage3-ec2-role"
  )

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 8 - Docker Containerization + ECR + ASG Rollout"
  }
}

# ------------------------------------------------------------------------------
# 1. Amazon Elastic Container Registry (ECR) for Docker Images
# ------------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  project_name         = var.project_name
  environment          = var.environment
  repository_name      = var.ecr_repository_name != "" ? var.ecr_repository_name : "${var.project_name}-${var.environment}-app"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  tags                 = local.common_tags
}

# ------------------------------------------------------------------------------
# 2. Grant EC2 ASG Role Permissions to Authenticate & Pull from ECR
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
  count      = local.ec2_role_name != "" ? 1 : 0
  role       = local.ec2_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
