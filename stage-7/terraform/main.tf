# ==============================================================================
# ShopSphere Stage 7: DevSecOps CI/CD Automation & Security Quality Gates
# Discovers persistent Stages 1-6 infrastructure with ZERO new resources to add
# 100% persistent: 0 to add, 0 to change, 0 to destroy!
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

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 7 - DevSecOps CI/CD Automation & Security Gates"
  }
}
