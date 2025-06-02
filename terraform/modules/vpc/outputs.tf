output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets."
  value       = aws_subnet.private[*].id
}

output "default_security_group_id" {
  description = "The ID of the default security group for the VPC."
  value       = aws_default_security_group.default.id
}

output "nat_gateway_ips" {
  description = "List of public Elastic IP addresses associated with NAT gateways."
  value       = aws_eip.nat[*].public_ip
}

output "availability_zones" {
  description = "Availability zones used by the VPC module."
  value       = var.availability_zones
}
