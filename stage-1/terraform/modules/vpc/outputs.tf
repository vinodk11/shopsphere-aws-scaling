output "vpc_id" {
  description = "The ID of the ShopSphere VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr_block" {
  description = "The CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
