output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "The ID of the primary public subnet (for backwards compatibility)"
  value       = aws_subnet.public[0].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across Multi-AZ"
  value       = aws_subnet.public[*].id
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs for Amazon RDS"
  value       = aws_subnet.private_db[*].id
}

output "private_cache_subnet_ids" {
  description = "List of private cache subnet IDs for Amazon ElastiCache Redis"
  value       = aws_subnet.private_cache[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
