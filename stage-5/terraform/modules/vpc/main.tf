# ==============================================================================
# VPC Module - Stage 4 Multi-AZ Multi-Tier Networking
# Public Tier (ALB & ASG) + Private DB Tier (RDS) + Private Cache Tier (ElastiCache)
# ==============================================================================

# 1. Dedicated VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# 2. Internet Gateway for Public Tier
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# 3. Public Subnets across Multi-AZ (ALB & ASG Compute Tier)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.public_availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
      Tier = "Public"
    }
  )
}

# 4. Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# 5. Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 6. Private Subnets for Amazon RDS Database Tier (Multi-AZ)
resource "aws_subnet" "private_db" {
  count                   = length(var.private_db_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = var.private_availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-db-subnet-${count.index + 1}"
      Tier = "Private-Database"
    }
  )
}

# 7. Private Subnets for Amazon ElastiCache Redis Tier (Multi-AZ)
resource "aws_subnet" "private_cache" {
  count                   = length(var.private_cache_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_cache_subnet_cidrs[count.index]
  availability_zone       = var.private_availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-cache-subnet-${count.index + 1}"
      Tier = "Private-Cache"
    }
  )
}

# 8. Private Route Table (Isolated internal tiers without internet routes)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
    }
  )
}

# 9. Private Route Table Associations (Database)
resource "aws_route_table_association" "private_db" {
  count          = length(var.private_db_subnet_cidrs)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private.id
}

# 10. Private Route Table Associations (Cache)
resource "aws_route_table_association" "private_cache" {
  count          = length(var.private_cache_subnet_cidrs)
  subnet_id      = aws_subnet.private_cache[count.index].id
  route_table_id = aws_route_table.private.id
}
