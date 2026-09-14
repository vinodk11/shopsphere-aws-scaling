provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# AWS WAFv2 Web ACL for CloudFront distributions must be created in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
