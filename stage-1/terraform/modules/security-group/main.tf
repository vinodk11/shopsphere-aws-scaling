# ==============================================================================
# Security Group Module - EC2 Instance Firewall
# ==============================================================================

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ShopSphere monolithic EC2 instance"
  vpc_id      = var.vpc_id

  # HTTP - Web Traffic to Nginx Reverse Proxy
  ingress {
    description = "Allow HTTP from web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_ingress_cidr
  }

  # HTTPS - Secure Web Traffic
  ingress {
    description = "Allow HTTPS from web"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_ingress_cidr
  }

  # SSH - Admin Access (Restricted)
  ingress {
    description = "Allow SSH from authorized administrator IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr
  }

  # Outbound - Allow all egress
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
    }
  )
}
