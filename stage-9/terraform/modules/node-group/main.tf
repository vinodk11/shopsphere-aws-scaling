# ==============================================================================
# Node Group Module - Stage 9 Managed Kubernetes Worker Nodes
# Creates IAM Role, Node Security Group, and Managed Multi-AZ EC2 Worker Fleet
# ==============================================================================

# 1. EKS Node Group IAM Role
resource "aws_iam_role" "node" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-role"
      Tier = "Compute-EKS-Workers"
    }
  )
}

# Attach standard EKS Worker Node policies
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# SSM access for zero-SSH management & debugging
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

# 2. Worker Node Security Group
resource "aws_security_group" "node" {
  name        = "${var.project_name}-${var.environment}-eks-node-sg"
  description = "Security group for all EKS worker nodes in the cluster"
  vpc_id      = var.vpc_id

  # Ingress from EKS Control Plane
  ingress {
    description     = "Allow control plane to communicate with pods & kubelet"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

  ingress {
    description     = "Allow control plane webhook communication"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

  # Ingress from ALB Security Group
  ingress {
    description     = "Allow HTTP traffic from ALB to pods/NodePorts"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Intra-cluster node communication
  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Egress to Internet and VPC resources (RDS, Redis, SQS)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.project_name}-${var.environment}-eks-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Allow RDS access from Node Security Group
resource "aws_security_group_rule" "rds_from_eks_nodes" {
  count                    = var.rds_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = var.rds_security_group_id
  description              = "Allow PostgreSQL access from EKS worker nodes"
}

# Allow Redis access from Node Security Group
resource "aws_security_group_rule" "redis_from_eks_nodes" {
  count                    = var.redis_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = var.redis_security_group_id
  description              = "Allow Redis access from EKS worker nodes"
}

# 3. EKS Managed Node Group
resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-${var.environment}-managed-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.instance_types
  capacity_type  = var.capacity_type # ON_DEMAND or SPOT
  disk_size      = var.disk_size

  labels = {
    role        = "worker"
    environment = var.environment
    project     = var.project_name
  }

  tags = merge(
    var.tags,
    {
      Name                                            = "${var.project_name}-${var.environment}-worker-node"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore
  ]
}
