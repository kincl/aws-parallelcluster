#!/bin/bash

# Generate AWS ParallelCluster configuration from Terraform outputs (simplified version)
# This script reads Terraform outputs without requiring jq

set -e

# Default values
TERRAFORM_DIR="../terraform"
OUTPUT_FILE="../cluster-config-generated.yaml"
SSH_KEY_NAME="jkincl"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --terraform-dir DIR    Path to Terraform directory (default: ../terraform)"
    echo "  -o, --output FILE          Output file path (default: ../pcluster/cluster-config-generated.yaml)"
    echo "  -k, --ssh-key KEY          SSH key name (default: jkincl)"
    echo "  -h, --help                 Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--terraform-dir)
            TERRAFORM_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_KEY_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if Terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo "Error: Terraform directory '$TERRAFORM_DIR' does not exist"
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Check if Terraform state exists
if [[ ! -f "terraform.tfstate" ]]; then
    echo "Error: Terraform state file not found. Please run 'terraform apply' first."
    exit 1
fi

echo "Reading Terraform outputs..."

# Extract values from Terraform outputs using simple text processing
REGION=$(terraform output -raw vpc_id | cut -d':' -f4 | cut -d'-' -f1-2 | tr -d '\n')
if [[ -z "$REGION" ]]; then
    # Fallback to variable if output parsing fails
    REGION="us-east-2"
fi

HEAD_NODE_SUBNET_ID=$(terraform output -raw head_node_subnet_id | tr -d '\n')
COMPUTE_SUBNET_ID=$(terraform output -raw compute_subnet_id | tr -d '\n')
SECURITY_GROUP_ID=$(terraform output -raw pcluster_security_group_id | tr -d '\n')
EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id | tr -d '\n')
CUSTOM_AMI=$(terraform output -raw custom_ami | tr -d '\n')
# EFS_ACCESS_POINT_ID removed - no longer using access points

# Validate that we got all required values
if [[ -z "$HEAD_NODE_SUBNET_ID" ]]; then
    echo "Error: Could not retrieve head node subnet ID from Terraform outputs"
    exit 1
fi

if [[ -z "$COMPUTE_SUBNET_ID" ]]; then
    echo "Error: Could not retrieve compute subnet ID from Terraform outputs"
    exit 1
fi

if [[ -z "$SECURITY_GROUP_ID" ]]; then
    echo "Error: Could not retrieve security group ID from Terraform outputs"
    exit 1
fi

if [[ -z "$EFS_FILE_SYSTEM_ID" ]]; then
    echo "Error: Could not retrieve EFS file system ID from Terraform outputs"
    exit 1
fi

echo "Terraform outputs retrieved successfully:"
echo "  Region: $REGION"
echo "  Head Node Subnet: $HEAD_NODE_SUBNET_ID"
echo "  Compute Subnet: $COMPUTE_SUBNET_ID"
echo "  Security Group: $SECURITY_GROUP_ID"
echo "  EFS File System: $EFS_FILE_SYSTEM_ID"
if [[ -n "$CUSTOM_AMI" ]]; then
    echo "  Custom AMI: $CUSTOM_AMI"
fi
# EFS Access Point output removed

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Generate the cluster configuration
echo "Generating cluster configuration..."

# Generate Image section with conditional CustomAmi
if [[ -n "$CUSTOM_AMI" ]]; then
    IMAGE_CONFIG="Region: $REGION
Image:
  Os: rhel9
  CustomAmi: $CUSTOM_AMI"
else
    IMAGE_CONFIG="Region: $REGION
Image:
  Os: rhel9"
fi

cat > "$OUTPUT_FILE" << EOF
$IMAGE_CONFIG
HeadNode:
  InstanceType: t3.medium
  Networking:
    SubnetId: $HEAD_NODE_SUBNET_ID
    ElasticIp: true
    SecurityGroups:
      - $SECURITY_GROUP_ID
  Ssh:
    KeyName: $SSH_KEY_NAME
Scheduling:
  Scheduler: slurm
  SlurmQueues:
  - Name: micro
    ComputeResources:
    - Name: t2micro
      InstanceType: t2.micro
      MinCount: 0
      MaxCount: 10
    Networking:
      SubnetIds:
      - $COMPUTE_SUBNET_ID
      SecurityGroups:
        - $SECURITY_GROUP_ID
  - Name: xlarge
    ComputeResources:
    - Name: c5xlarge
      InstanceType: c5.xlarge
      MinCount: 0
      MaxCount: 5
    Networking:
      SubnetIds:
      - $COMPUTE_SUBNET_ID
      SecurityGroups:
        - $SECURITY_GROUP_ID
SharedStorage:
  - MountDir: /shared
    Name: shared-efs
    StorageType: Efs
    EfsSettings:
      FileSystemId: $EFS_FILE_SYSTEM_ID
EOF

# EFS Access Point section removed - no longer using access points

echo ""
echo "Cluster configuration generated successfully!"
echo "Output file: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Review the generated configuration file"
echo "2. Customize instance types, queue configurations, or other settings as needed"
echo "3. Run: pcluster create-cluster --cluster-name my-cluster --cluster-configuration $OUTPUT_FILE"
echo ""
echo "Note: Make sure you have the SSH key '$SSH_KEY_NAME' available in your AWS account"
echo "      and that you have the necessary AWS CLI configuration and permissions."
