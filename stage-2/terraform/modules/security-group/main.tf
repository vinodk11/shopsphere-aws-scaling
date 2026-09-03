# ==============================================================================
# Security Group Module - Stage 2 Firewalls (EC2 Tier + RDS Tier)
# ==============================================================================

# 1. EC2 Instance Security Group (Web / App Tier)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ShopSphere EC2 application server"
  vpc_id      = var.vpc_id

  # HTTP - Public web traffic
  ingress {
    description = "Allow HTTP from web clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_ingress_cidr
  }

  # HTTPS - Public secure web traffic
  ingress {
    description = "Allow HTTPS from web clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_ingress_cidr
  }

  # SSH - Administrator remote access
  ingress {
    description = "Allow SSH from authorized administrator IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr
  }

  # Outbound - Allow all egress (package downloads, RDS connectivity)
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
      Tier = "Public-Compute"
    }
  )
}

# 2. RDS PostgreSQL Security Group (Database Tier)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for ShopSphere Amazon RDS PostgreSQL database"
  vpc_id      = var.vpc_id

  # PostgreSQL - Strictly restricted to EC2 Security Group ONLY
  ingress {
    description     = "Allow PostgreSQL access strictly from EC2 application tier"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Egress - Allow outbound within VPC if needed for updates/replication
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
      Tier = "Private-Database"
    }
  )
}
