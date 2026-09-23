# ==============================================================================
# ShopSphere Stage 5: Asynchronous Order Processing Tier (Amazon SQS + AWS Lambda)
# Discovers Stage 1-4 infrastructure (VPC, RDS, ASG EC2 IAM Role, ALB)
# Provisions ONLY the SQS Queues, Lambda Worker, and IAM Policies
# Keeps Stages 1-4 completely persistent with ZERO resources destroyed!
# ==============================================================================

locals {
  # 1. Resolve VPC from Stage 1
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.stage1[0].id

  # 2. Resolve RDS Endpoint from Stage 2
  db_host = var.db_host != "" ? var.db_host : (
    length(try(data.aws_db_instance.stage2_rds, [])) > 0 ? data.aws_db_instance.stage2_rds[0].address : ""
  )

  # 3. Resolve ASG EC2 IAM Role Name from Stage 3
  ec2_role_name = var.ec2_role_name != "" ? var.ec2_role_name : (
    length(try(data.aws_iam_role.asg_ec2, [])) > 0 ? data.aws_iam_role.asg_ec2[0].name : "${var.project_name}-stage3-ec2-role"
  )

  # 4. Resolve ALB DNS Name from Stage 3
  alb_dns_name = var.alb_dns_name != "" ? var.alb_dns_name : (
    var.alb_arn != "" ? try(data.aws_lb.alb[0].dns_name, "") : try(data.aws_lb.alb_by_tag[0].dns_name, "")
  )

  common_tags = {
    Project     = "ShopSphere"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "Stage 5 - Amazon SQS + AWS Lambda Asynchronous Order Processing"
  }
}

# ------------------------------------------------------------------------------
# 1. Amazon SQS Message Queues (Main Queue + DLQ + Redrive Policy)
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
# 2. IAM Roles & Policies (EC2 Publisher & Lambda Consumer)
# ------------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  sqs_queue_arn = module.sqs.queue_arn
  ec2_role_name = local.ec2_role_name
  tags          = local.common_tags
}

# ------------------------------------------------------------------------------
# 3. AWS Lambda Serverless Worker & SQS Event Source Mapping
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
    DB_HOST                     = local.db_host
    DB_PORT                     = tostring(var.db_port)
    DB_NAME                     = var.db_name
    DB_USER                     = var.db_user
    DB_PASSWORD                 = var.db_password
  }

  tags = local.common_tags
}
