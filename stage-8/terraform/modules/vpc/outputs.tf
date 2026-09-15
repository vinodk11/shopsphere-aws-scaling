# ==============================================================================
# VPC Module Outputs - Stage 4
# ==============================================================================

output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets (ALB & EC2 ASG tier)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_db_subnet_ids" {
  description = "List of IDs of private subnets for Amazon RDS"
  value       = aws_subnet.private_db[*].id
}

output "private_cache_subnet_ids" {
  description = "List of IDs of private subnets for Amazon ElastiCache Redis"
  value       = aws_subnet.private_cache[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
