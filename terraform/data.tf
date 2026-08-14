data "aws_ami" "amazon_linux_2023" {
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}