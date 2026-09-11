# ==============================================================================
# Security Group Module - Stage 3 Tiered Firewalls
# ALB Tier (Public) -> EC2 ASG Tier (Private/ALB-restricted) -> RDS Tier (EC2-restricted)
# ==============================================================================

# 1. ALB Security Group (Public Edge Tier)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ShopSphere Application Load Balancer"
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

  # Outbound - Allow all egress to route traffic to backend EC2 instances
  egress {
    description      = "Allow all outbound traffic to targets"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Tier = "Public-ALB"
    }
  )
}

# 2. EC2 ASG Security Group (Compute Tier)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ShopSphere Auto Scaling Group EC2 instances"
  vpc_id      = var.vpc_id

  # HTTP - Ingress strictly allowed from ALB Security Group ONLY
  ingress {
    description     = "Allow HTTP traffic strictly from Application Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH - Administrator remote access
  ingress {
    description = "Allow SSH from authorized administrator IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr
  }

  # Outbound - Allow all egress (package downloads, git cloning, RDS connectivity)
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
      Tier = "Compute-ASG"
    }
  )
}

# 3. RDS PostgreSQL Security Group (Database Tier)
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

  # Egress - Outbound within VPC
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
