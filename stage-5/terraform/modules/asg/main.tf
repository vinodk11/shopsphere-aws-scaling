# ==============================================================================
# ASG Module - Stage 4 EC2 Auto Scaling Group & Launch Template
# Implements horizontal scalability, dynamic elasticity, and self-healing multi-AZ compute.
# ==============================================================================

locals {
  instance_profile_name = var.iam_instance_profile_name != null ? var.iam_instance_profile_name : (length(aws_iam_instance_profile.this) > 0 ? aws_iam_instance_profile.this[0].name : null)
}

# 1. IAM Role for EC2 Auto Scaling Instances (SSM Session Manager) - fallback if not provided
resource "aws_iam_role" "this" {
  count = var.iam_instance_profile_name == null ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ec2-role"

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

# Attach SSM Managed Policy
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.iam_instance_profile_name == null ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "this" {
  count = var.iam_instance_profile_name == null ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role  = aws_iam_role.this[0].name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-instance-profile"
    }
  )
}

# 2. EC2 Launch Template
resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = local.instance_profile_name
  }

  vpc_security_group_ids = [var.security_group_id]

  user_data = base64encode(var.user_data)

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-asg-instance"
        Tier = "Compute-ASG"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-asg-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lt"
    }
  )
}

# 3. Auto Scaling Group across Multi-AZ Subnets
resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.project_name}-${var.environment}-asg-"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  dynamic "tag" {
    for_each = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-asg-node"
        Tier = "Compute-ASG"
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# 4. Target Tracking Auto Scaling Policy (Average CPU Utilization)
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project_name}-${var.environment}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}
