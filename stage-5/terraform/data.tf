# ==============================================================================
# Data Sources — Stage 5
# ==============================================================================

# Query available Availability Zones in the selected AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# Dynamically lookup the latest Amazon Linux 2023 AMI (HVM, 64-bit x86, gp3)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
