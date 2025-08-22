# Outputs for AWS ParallelCluster Infrastructure

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.pcluster_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.pcluster_vpc.cidr_block
}

# Subnet Information
output "head_node_subnet_id" {
  description = "ID of the head node subnet (public)"
  value       = aws_subnet.head_node_subnet.id
}

output "compute_subnet_id" {
  description = "ID of the compute subnet (private)"
  value       = aws_subnet.compute_subnet.id
}

output "head_node_subnet_cidr" {
  description = "CIDR block of the head node subnet"
  value       = aws_subnet.head_node_subnet.cidr_block
}

output "compute_subnet_cidr" {
  description = "CIDR block of the compute subnet"
  value       = aws_subnet.compute_subnet.cidr_block
}

output "head_node_availability_zone" {
  description = "Availability zone used for the head node subnet"
  value       = aws_subnet.head_node_subnet.availability_zone
}

output "compute_availability_zone" {
  description = "Availability zone used for the compute subnet"
  value       = aws_subnet.compute_subnet.availability_zone
}

# Security Groups
output "pcluster_security_group_id" {
  description = "ID of the ParallelCluster nodes security group"
  value       = aws_security_group.pcluster_sg.id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs_sg.id
}

# EFS Information
output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.shared_storage.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.shared_storage.dns_name
}

output "efs_access_point_id" {
  description = "ID of the EFS access point for shared directory"
  value       = aws_efs_access_point.shared_access_point.id
}

# NAT Gateway
output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.pcluster_nat.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

# Internet Gateway
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.pcluster_igw.id
}

# For ParallelCluster Configuration
output "pcluster_config_values" {
  description = "Values to use in ParallelCluster configuration"
  value = {
    region              = var.aws_region
    head_node_subnet_id = aws_subnet.head_node_subnet.id
    compute_subnet_ids  = [aws_subnet.compute_subnet.id]
    efs_file_system_id  = aws_efs_file_system.shared_storage.id
    security_group_id   = aws_security_group.pcluster_sg.id
    vpc_id              = aws_vpc.pcluster_vpc.id
  }
}
