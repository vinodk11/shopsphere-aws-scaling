# ==============================================================================
# Global & Environment Variables — Stage 6 (CloudFront + WAF + SQS + Lambda + Redis + RDS)
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region to deploy ShopSphere resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "The deployment environment stage"
  type        = string
  default     = "stage6"
}

# ------------------------------------------------------------------------------
# Network Variables
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "The CIDR block for the dedicated ShopSphere VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks for public subnets (ALB and EC2 ASG tier across multi-AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "The CIDR blocks for private database subnets (Amazon RDS Tier)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_cache_subnet_cidrs" {
  description = "The CIDR blocks for private cache subnets (Amazon ElastiCache Redis Tier)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "availability_zones" {
  description = "Explicit list of Availability Zones to use (leave null to dynamically select first 2 AZs in region)"
  type        = list(string)
  default     = null
}

# ------------------------------------------------------------------------------
# Security Variables
# ------------------------------------------------------------------------------

variable "admin_cidr" {
  description = "List of IPv4 CIDR blocks authorized for SSH administrative access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# EC2 Auto Scaling & Compute Variables
# ------------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance size for the application server"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size of the encrypted root EBS volume in GB"
  type        = number
  default     = 20
}

variable "ssh_key_name" {
  description = "Optional name of existing AWS EC2 KeyPair for SSH key-based access"
  type        = string
  default     = null
}

variable "custom_ami_id" {
  description = "Optional custom AMI ID override (if omitted, latest Amazon Linux 2023 is resolved dynamically)"
  type        = string
  default     = null
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_target_cpu_utilization" {
  description = "Target CPU utilization percentage for dynamic auto-scaling"
  type        = number
  default     = 70.0
}

# ------------------------------------------------------------------------------
# Application Configuration Variables
# ------------------------------------------------------------------------------

variable "app_port" {
  description = "Internal listening port for the ShopSphere application server"
  type        = number
  default     = 8080
}

variable "app_repo_url" {
  description = "Git repository URL to clone ShopSphere application source from"
  type        = string
  default     = "https://github.com/vinodk11/shopsphere-aws-scaling.git"
}

# ------------------------------------------------------------------------------
# Amazon RDS PostgreSQL Database Variables
# ------------------------------------------------------------------------------

variable "db_name" {
  description = "The database name to create on Amazon RDS"
  type        = string
  default     = "shopspheredb"
}

variable "db_user" {
  description = "The master username for Amazon RDS PostgreSQL"
  type        = string
  default     = "shopsphere_user"
}

variable "db_password" {
  description = "The master password for Amazon RDS PostgreSQL"
  type        = string
  sensitive   = true
  default     = "ShopSphere2026SecurePass!"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version on Amazon RDS"
  type        = string
  default     = "15.7"
}

variable "db_instance_class" {
  description = "The instance class for Amazon RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Upper storage auto-scaling threshold in GB for RDS"
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ synchronous standby replica for RDS"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip creating final RDS snapshot during destruction"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated daily backups"
  type        = number
  default     = 7
}

# ------------------------------------------------------------------------------
# Amazon ElastiCache Redis Variables
# ------------------------------------------------------------------------------

variable "cache_node_type" {
  description = "Compute and memory capacity for the ElastiCache Redis node"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version on Amazon ElastiCache"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Port for the Redis cluster"
  type        = number
  default     = 6379
}

# ------------------------------------------------------------------------------
# Amazon SQS Queue Variables
# ------------------------------------------------------------------------------

variable "sqs_queue_name" {
  description = "Name of the main order processing SQS queue"
  type        = string
  default     = ""
}

variable "sqs_dlq_name" {
  description = "Name of the dead-letter SQS queue"
  type        = string
  default     = ""
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout in seconds for the SQS order queue"
  type        = number
  default     = 60
}

variable "sqs_message_retention_seconds" {
  description = "Number of seconds SQS retains messages in the main queue"
  type        = number
  default     = 345600
}

variable "sqs_max_receive_count" {
  description = "Maximum delivery attempts before an unacknowledged order message is routed to the DLQ"
  type        = number
  default     = 3
}

variable "sqs_managed_sse_enabled" {
  description = "Enable SQS-managed server-side encryption (SSE-SQS)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# AWS Lambda Worker Variables
# ------------------------------------------------------------------------------

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = ""
}

variable "lambda_runtime" {
  description = "Node.js Lambda runtime version"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Lambda function execution timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory allocated to the Lambda worker function in MB"
  type        = number
  default     = 256
}

variable "lambda_batch_size" {
  description = "Batch size for SQS message consumption by Lambda"
  type        = number
  default     = 10
}

variable "lambda_maximum_batching_window_in_seconds" {
  description = "Maximum batching window in seconds for SQS polling"
  type        = number
  default     = 5
}

variable "lambda_log_retention_in_days" {
  description = "Days to retain CloudWatch logs for the Lambda function"
  type        = number
  default     = 14
}

# ------------------------------------------------------------------------------
# Amazon CloudFront CDN Variables (Stage 6)
# ------------------------------------------------------------------------------

variable "cloudfront_price_class" {
  description = "Price class for CloudFront distribution (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_custom_header_name" {
  description = "Name of the verification header injected by CloudFront to ALB"
  type        = string
  default     = "X-Origin-Verify"
}

variable "cloudfront_custom_header_secret" {
  description = "Secret token for CloudFront to ALB origin verification header"
  type        = string
  sensitive   = true
  default     = "ShopSphereEdgeSecretToken2026Verify"
}

variable "enable_alb_header_lockdown" {
  description = "Enable ALB lockdown to drop requests lacking the CloudFront origin verification header"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# AWS WAF v2 Variables (Stage 6)
# ------------------------------------------------------------------------------

variable "waf_rate_limit" {
  description = "Rate limit of requests per 5 minutes per IP"
  type        = number
  default     = 500
}

variable "waf_enable_rate_limit" {
  description = "Enable IP rate-based flood protection rule"
  type        = bool
  default     = true
}

variable "waf_enable_common_rule_set" {
  description = "Enable AWS Managed Common Rule Set (OWASP Top 10)"
  type        = bool
  default     = true
}

variable "waf_enable_known_bad_inputs_rule_set" {
  description = "Enable AWS Managed Known Bad Inputs Rule Set"
  type        = bool
  default     = true
}

variable "waf_enable_ip_reputation_rule_set" {
  description = "Enable AWS Managed IP Reputation Rule Set"
  type        = bool
  default     = true
}
