# ==============================================================================
# IAM Module — Stage 5 Least-Privilege IAM Roles and Policies
# EC2 ASG Fleet (Publisher) & AWS Lambda Worker (Consumer)
# ==============================================================================

# ==============================================================================
# 1. EC2 ASG Instance IAM Role & Instance Profile (SQS Publisher)
# ==============================================================================

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-asg-role"

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
      Name = "${var.project_name}-${var.environment}-ec2-asg-role"
      Tier = "Compute-ASG"
    }
  )
}

# Attach AWS SSM Managed Policy for secure remote access without open SSH
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SQS Publisher Policy for EC2 Fleet
resource "aws_iam_policy" "ec2_sqs_publish" {
  name        = "${var.project_name}-${var.environment}-ec2-sqs-publish-policy"
  description = "Allows ShopSphere EC2 instances to publish order messages to SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = [var.sqs_queue_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_sqs" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_sqs_publish.arn
}

# EC2 IAM Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-instance-profile"
    }
  )
}

# ==============================================================================
# 2. Lambda Serverless Worker IAM Role (SQS Consumer)
# ==============================================================================

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-worker-role"
      Tier = "Serverless-Worker"
    }
  )
}

# Attach AWS Lambda Basic Execution Role for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS Consumer Policy for AWS Lambda Event Source Polling
resource "aws_iam_policy" "lambda_sqs_consume" {
  name        = "${var.project_name}-${var.environment}-lambda-sqs-consume-policy"
  description = "Allows Lambda worker to poll, consume, and delete processed messages from SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [var.sqs_queue_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_sqs_consume.arn
}

# Attach AWS ECR Read Only Policy for pulling container images from ECR
resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
