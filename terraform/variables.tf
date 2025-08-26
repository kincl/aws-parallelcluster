# Variables for AWS ParallelCluster Infrastructure

variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the ParallelCluster"
  type        = string
  default     = "pcluster"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "head_node_subnet_cidr" {
  description = "CIDR block for the head node subnet (public)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "compute_subnet_cidr" {
  description = "CIDR block for the compute subnet (private)"
  type        = string
  default     = "10.0.2.0/24"
}



# Security Configuration
variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the head node"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "ssh_key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

# EFS Configuration
variable "efs_encrypted" {
  description = "Enable encryption for EFS file system"
  type        = bool
  default     = true
}

variable "efs_performance_mode" {
  description = "EFS performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "EFS performance mode must be either 'generalPurpose' or 'maxIO'."
  }
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode (bursting or provisioned)"
  type        = string
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned"], var.efs_throughput_mode)
    error_message = "EFS throughput mode must be either 'bursting' or 'provisioned'."
  }
}

variable "efs_provisioned_throughput" {
  description = "Provisioned throughput in MiB/s (only used if throughput_mode is provisioned)"
  type        = number
  default     = 100
}



# Image Builder Configuration
variable "imagebuilder_instance_type" {
  description = "Instance type for Image Builder builds"
  type        = string
  default     = "c5.xlarge"
}

variable "imagebuilder_root_volume_size" {
  description = "Root volume size in GB for the custom image"
  type        = number
  default     = 45
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
