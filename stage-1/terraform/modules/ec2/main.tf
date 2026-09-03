# ==============================================================================
# EC2 Module - Stage 1 Single Server Instance
# ==============================================================================

# IAM Role for EC2 Instance (Allows AWS Systems Manager Session Manager access)
resource "aws_iam_role" "this" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-role"
    }
  )
}

# Attach SSM Managed Policy so instance can be managed/accessed via SSM
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.this.name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-instance-profile"
    }
  )
}

# EC2 Instance
resource "aws_instance" "this" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.this.name
  key_name             = var.key_name

  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-root-volume"
      }
    )
  }

  user_data                   = var.user_data
  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2"
    }
  )
}
