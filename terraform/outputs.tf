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

# SSH Key Name
output "ssh_key_name" {
  description = "SSH key name for cluster access"
  value       = var.ssh_key_name
}

# Image Builder Information
output "pcluster_parent_image_id" {
  description = "AMI ID of the ParallelCluster RHEL9 parent image"
  value       = data.aws_ami.pcluster_rhel9.id
}

output "pcluster_parent_image_name" {
  description = "Name of the ParallelCluster RHEL9 parent image"
  value       = data.aws_ami.pcluster_rhel9.name
}

output "imagebuilder_s3_bucket" {
  description = "S3 bucket name for Image Builder scripts"
  value       = aws_s3_bucket.imagebuilder_scripts.bucket
}

output "imagebuilder_script_s3_url" {
  description = "S3 URL for the custom Image Builder script"
  value       = "s3://${aws_s3_bucket.imagebuilder_scripts.bucket}/${aws_s3_object.custom_script.key}"
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
    ssh_key_name        = var.ssh_key_name
    parent_image_id     = data.aws_ami.pcluster_rhel9.id
    s3_bucket           = aws_s3_bucket.imagebuilder_scripts.bucket
    script_s3_url       = "s3://${aws_s3_bucket.imagebuilder_scripts.bucket}/${aws_s3_object.custom_script.key}"
  }
}
