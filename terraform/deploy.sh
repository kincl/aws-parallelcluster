#!/bin/bash

# AWS ParallelCluster Infrastructure Deployment Script
# This script helps deploy the Terraform infrastructure for AWS ParallelCluster

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform >= 1.0"
        echo "Visit: https://www.terraform.io/downloads"
        exit 1
    fi

    # Check terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    print_status "Terraform version: $TERRAFORM_VERSION"

    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install and configure AWS CLI"
        echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured properly"
        echo "Run: aws configure"
        exit 1
    fi

    # Show current AWS identity
    AWS_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")
    print_status "AWS Identity: $AWS_IDENTITY"

    print_success "Prerequisites check completed"
}

setup_tfvars() {
    if [ ! -f "$SCRIPT_DIR/terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp "$SCRIPT_DIR/terraform.tfvars.example" "$SCRIPT_DIR/terraform.tfvars"
        print_status "Created terraform.tfvars from example"
        print_warning "Please review and customize terraform.tfvars before proceeding"
        read -p "Press Enter to continue after customizing terraform.tfvars, or Ctrl+C to exit..."
    else
        print_status "Using existing terraform.tfvars"
    fi
}

terraform_init() {
    print_status "Initializing Terraform..."
    cd "$SCRIPT_DIR"
    terraform init
    print_success "Terraform initialization completed"
}

terraform_plan() {
    print_status "Creating Terraform plan..."
    cd "$SCRIPT_DIR"
    terraform plan -out=tfplan
    print_success "Terraform plan created successfully"
}

terraform_apply() {
    print_status "Applying Terraform configuration..."
    cd "$SCRIPT_DIR"

    echo
    print_warning "This will create AWS resources that may incur costs!"
    echo "Resources to be created:"
    echo "  - VPC with public and private subnets"
    echo "  - Internet Gateway and NAT Gateway (charges apply)"
    echo "  - EFS File System (charges based on usage)"
    echo "  - Security Groups"
    echo "  - Elastic IP for NAT Gateway"
    echo

    read -p "Do you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi

    terraform apply tfplan
    print_success "Terraform deployment completed successfully!"
}

show_outputs() {
    print_status "Deployment outputs:"
    cd "$SCRIPT_DIR"
    terraform output

    echo
    print_status "Important values for ParallelCluster configuration:"
    echo "Head Node Subnet ID: $(terraform output -raw head_node_subnet_id)"
    echo "Compute Subnet ID: $(terraform output -raw compute_subnet_id)"
    echo "EFS File System ID: $(terraform output -raw efs_file_system_id)"
    echo "Security Group ID: $(terraform output -raw pcluster_security_group_id)"
}

update_cluster_config() {
    PCLUSTER_CONFIG="$SCRIPT_DIR/../pcluster/cluster-config.yaml"

    if [ -f "$PCLUSTER_CONFIG" ]; then
        print_status "Would you like to update the cluster configuration with new resource IDs?"
        read -p "Update cluster-config.yaml? (yes/no): " -r

        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            # Create backup
            cp "$PCLUSTER_CONFIG" "$PCLUSTER_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

            # Get values from terraform output
            HEAD_SUBNET=$(terraform output -raw head_node_subnet_id)
            COMPUTE_SUBNET=$(terraform output -raw compute_subnet_id)
            EFS_ID=$(terraform output -raw efs_file_system_id)

            print_status "Creating updated cluster configuration..."
            print_warning "Please manually update your cluster-config.yaml with these values:"
            echo "  HeadNode SubnetId: $HEAD_SUBNET"
            echo "  Compute SubnetIds: [$COMPUTE_SUBNET]"
            echo "  EFS FileSystemId: $EFS_ID"
        fi
    fi
}

cleanup() {
    print_status "Cleaning up temporary files..."
    cd "$SCRIPT_DIR"
    [ -f "tfplan" ] && rm -f tfplan
    print_success "Cleanup completed"
}

show_help() {
    echo "AWS ParallelCluster Infrastructure Deployment Script"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  deploy    - Full deployment (init, plan, apply)"
    echo "  init      - Initialize Terraform"
    echo "  plan      - Create Terraform plan"
    echo "  apply     - Apply Terraform plan"
    echo "  destroy   - Destroy infrastructure"
    echo "  output    - Show Terraform outputs"
    echo "  help      - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 deploy   # Full deployment"
    echo "  $0 plan     # Just create a plan"
    echo "  $0 destroy  # Destroy infrastructure"
}

destroy_infrastructure() {
    print_warning "This will DESTROY all AWS resources created by this Terraform configuration!"
    echo
    print_error "WARNING: This action cannot be undone!"
    echo "The following resources will be destroyed:"
    echo "  - VPC and all associated networking"
    echo "  - EFS File System (all data will be lost!)"
    echo "  - Security Groups"
    echo "  - NAT Gateway and Elastic IP"
    echo

    read -p "Are you absolutely sure you want to destroy all resources? Type 'yes' to confirm: " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Destruction cancelled"
        exit 0
    fi

    print_status "Destroying infrastructure..."
    cd "$SCRIPT_DIR"
    terraform destroy
    print_success "Infrastructure destroyed"
}

# Main script logic
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            setup_tfvars
            terraform_init
            terraform_plan
            terraform_apply
            show_outputs
            update_cluster_config
            cleanup
            ;;
        "init")
            check_prerequisites
            terraform_init
            ;;
        "plan")
            check_prerequisites
            setup_tfvars
            terraform_init
            terraform_plan
            ;;
        "apply")
            check_prerequisites
            cd "$SCRIPT_DIR"
            if [ ! -f "tfplan" ]; then
                print_error "No plan file found. Run 'plan' first or use 'deploy' command"
                exit 1
            fi
            terraform_apply
            show_outputs
            cleanup
            ;;
        "destroy")
            check_prerequisites
            cd "$SCRIPT_DIR"
            destroy_infrastructure
            ;;
        "output")
            check_prerequisites
            cd "$SCRIPT_DIR"
            show_outputs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
