resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ShopSphere Stage 1 EC2 instance"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  description       = "HTTP from the public internet"
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  description       = "HTTPS from the public internet"
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.admin_cidr)

  description       = "SSH from admin CIDR ${each.value}"
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  description       = "Allow all outbound traffic"
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
