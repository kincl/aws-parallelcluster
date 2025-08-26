# AWS ParallelCluster Infrastructure
# This Terraform configuration creates the base infrastructure needed for AWS ParallelCluster
# including VPC, subnets, security groups, and EFS storage

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Get the latest ParallelCluster RHEL9 AMI
data "aws_ami" "pcluster_rhel9" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["aws-parallelcluster-3*-rhel9*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# VPC
resource "aws_vpc" "pcluster_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "pcluster_igw" {
  vpc_id = aws_vpc.pcluster_vpc.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }
}

# Public Subnet for Head Node
resource "aws_subnet" "head_node_subnet" {
  vpc_id                  = aws_vpc.pcluster_vpc.id
  cidr_block              = var.head_node_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cluster_name}-head-node-subnet"
    Environment = var.environment
    Purpose     = "ParallelCluster-HeadNode"
  }
}

# Private Subnet for Compute Nodes (same AZ as head node)
resource "aws_subnet" "compute_subnet" {
  vpc_id            = aws_vpc.pcluster_vpc.id
  cidr_block        = var.compute_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.cluster_name}-compute-subnet"
    Environment = var.environment
    Purpose     = "ParallelCluster-Compute"
  }
}

# NAT Gateway for private subnet internet access
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.pcluster_igw]

  tags = {
    Name        = "${var.cluster_name}-nat-eip"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }
}

resource "aws_nat_gateway" "pcluster_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.head_node_subnet.id

  tags = {
    Name        = "${var.cluster_name}-nat-gateway"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }

  depends_on = [aws_internet_gateway.pcluster_igw]
}




# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.pcluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pcluster_igw.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.pcluster_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.pcluster_nat.id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt"
    Environment = var.environment
    Purpose     = "ParallelCluster"
  }
}



# Route Table Associations
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.head_node_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.compute_subnet.id
  route_table_id = aws_route_table.private_rt.id
}



# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = aws_vpc.pcluster_vpc.id
  description = "Security group for EFS access from ParallelCluster"

  ingress {
    description = "NFS from ParallelCluster subnets"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.head_node_subnet_cidr, var.compute_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-efs-sg"
    Environment = var.environment
    Purpose     = "ParallelCluster-EFS"
  }
}

# Security Group for ParallelCluster nodes
resource "aws_security_group" "pcluster_sg" {
  name_prefix = "${var.cluster_name}-nodes-"
  vpc_id      = aws_vpc.pcluster_vpc.id
  description = "Security group for ParallelCluster nodes"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }

  # Internal cluster communication
  ingress {
    description = "Internal cluster communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # SLURM communication
  ingress {
    description = "SLURM slurmctld"
    from_port   = 6817
    to_port     = 6818
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "SLURM slurmd"
    from_port   = 6818
    to_port     = 6818
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-nodes-sg"
    Environment = var.environment
    Purpose     = "ParallelCluster-Nodes"
  }
}

# EFS File System
resource "aws_efs_file_system" "shared_storage" {
  creation_token = "${var.cluster_name}-shared-efs"
  encrypted      = var.efs_encrypted

  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode

  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput : null

  tags = {
    Name        = "${var.cluster_name}-shared-efs"
    Environment = var.environment
    Purpose     = "ParallelCluster-SharedStorage"
  }
}

# EFS Mount Target (only one needed since both subnets are in same AZ)
resource "aws_efs_mount_target" "shared_mt" {
  file_system_id  = aws_efs_file_system.shared_storage.id
  subnet_id       = aws_subnet.compute_subnet.id
  security_groups = [aws_security_group.efs_sg.id]
}

# S3 Bucket for Image Builder scripts
resource "aws_s3_bucket" "imagebuilder_scripts" {
  bucket = "${var.cluster_name}-imagebuilder-scripts-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.cluster_name}-imagebuilder-scripts"
    Environment = var.environment
    Purpose     = "ParallelCluster-ImageBuilder"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "imagebuilder_scripts" {
  bucket = aws_s3_bucket.imagebuilder_scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "imagebuilder_scripts" {
  bucket = aws_s3_bucket.imagebuilder_scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "imagebuilder_scripts" {
  bucket = aws_s3_bucket.imagebuilder_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload the custom script to S3
resource "aws_s3_object" "custom_script" {
  bucket = aws_s3_bucket.imagebuilder_scripts.id
  key    = "custom-image-script.sh"
  source = "${path.module}/custom-image-script.sh"
  etag   = filemd5("${path.module}/custom-image-script.sh")

  tags = {
    Name        = "custom-image-script"
    Environment = var.environment
    Purpose     = "ParallelCluster-ImageBuilder"
  }
}

# Template file for cluster configuration
resource "local_file" "cluster_config" {
  content = templatefile("${path.module}/cluster-config-template.yaml", {
    region              = var.aws_region
    head_node_subnet_id = aws_subnet.head_node_subnet.id
    compute_subnet_id   = aws_subnet.compute_subnet.id
    security_group_id   = aws_security_group.pcluster_sg.id
    efs_file_system_id  = aws_efs_file_system.shared_storage.id
    ssh_key_name        = var.ssh_key_name
  })

  filename = "${path.module}/../cluster-config-generated.yaml"

  depends_on = [
    aws_subnet.head_node_subnet,
    aws_subnet.compute_subnet,
    aws_security_group.pcluster_sg,
    aws_efs_file_system.shared_storage
  ]
}

# Template file for Image Builder configuration
resource "local_file" "imagebuilder_config" {
  content = templatefile("${path.module}/imagebuilder-config-template.yaml", {
    region               = var.aws_region
    cluster_name         = var.cluster_name
    parent_image_id      = data.aws_ami.pcluster_rhel9.id
    head_node_subnet_id  = aws_subnet.head_node_subnet.id
    security_group_id    = aws_security_group.pcluster_sg.id
    environment          = var.environment
    instance_type        = var.imagebuilder_instance_type
    root_volume_size     = var.imagebuilder_root_volume_size
    script_s3_url        = "s3://${aws_s3_bucket.imagebuilder_scripts.bucket}/${aws_s3_object.custom_script.key}"
  })

  filename = "${path.module}/../imagebuilder-config-generated.yaml"

  depends_on = [
    aws_subnet.head_node_subnet,
    aws_security_group.pcluster_sg,
    data.aws_ami.pcluster_rhel9,
    aws_s3_object.custom_script
  ]
}
