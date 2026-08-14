terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  locals {
    common_tags = {
      Project     = "ShopSphere"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stage       = "1"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}