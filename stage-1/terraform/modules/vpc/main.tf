# ==============================================================================
# VPC Module - Stage 1 Dedicated Multi-Tier Multi-AZ Networking
# Provides persistent Public, Private-DB, and Private-Cache subnets for all 10 stages
# ==============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-vpc"
      Project = "ShopSphere"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-igw"
      Project = "ShopSphere"
    }
  )
}

locals {
  public_cidrs = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [var.public_subnet_cidr]
  azs          = length(var.availability_zones) > 0 ? var.availability_zones : (var.availability_zone != null ? [var.availability_zone] : [])
}

# 1. Public Subnets across Multi-AZ (Stage 1 EC2 Monolith, Stage 3 ALB & ASG, Stage 9 EKS)
resource "aws_subnet" "public" {
  count                   = length(local.public_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = length(local.azs) > 0 ? local.azs[count.index % length(local.azs)] : null
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
      Tier    = "Public"
      Project = "ShopSphere"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-public-rt"
      Project = "ShopSphere"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 2. Private Subnets for Amazon RDS Database Tier (Multi-AZ for Stage 2+)
resource "aws_subnet" "private_db" {
  count                   = length(var.private_db_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = length(local.azs) > 0 ? local.azs[count.index % length(local.azs)] : null
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-private-db-subnet-${count.index + 1}"
      Tier    = "Private-Database"
      Project = "ShopSphere"
    }
  )
}

# 3. Private Subnets for Amazon ElastiCache Redis Tier (Multi-AZ for Stage 4+)
resource "aws_subnet" "private_cache" {
  count                   = length(var.private_cache_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_cache_subnet_cidrs[count.index]
  availability_zone       = length(local.azs) > 0 ? local.azs[count.index % length(local.azs)] : null
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-private-cache-subnet-${count.index + 1}"
      Tier    = "Private-Cache"
      Project = "ShopSphere"
    }
  )
}

# 4. Isolated Private Route Table (Internal tiers without internet routes)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-private-rt"
      Project = "ShopSphere"
    }
  )
}

resource "aws_route_table_association" "private_db" {
  count          = length(var.private_db_subnet_cidrs)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_cache" {
  count          = length(var.private_cache_subnet_cidrs)
  subnet_id      = aws_subnet.private_cache[count.index].id
  route_table_id = aws_route_table.private.id
}
