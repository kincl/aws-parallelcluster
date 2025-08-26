#!/bin/bash

# AWS ParallelCluster Custom Image Builder Helper Script
# This script helps build and manage custom ParallelCluster AMIs using Image Builder

set -e  # Exit on any error

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONFIG_FILE="../imagebuilder-config-generated.yaml"
IMAGE_ID=""
ACTION=""
WAIT_FOR_COMPLETION=false
TIMEOUT=3600  # 1 hour default timeout

# Function to print colored output
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

# Function to show usage
show_usage() {
    cat << EOF
AWS ParallelCluster Custom Image Builder Helper

USAGE:
    $0 build [OPTIONS]                    # Build a new custom image
    $0 status <image-id>                  # Check build status
    $0 list                               # List all custom images
    $0 delete <image-id>                  # Delete a custom image
    $0 update-cluster <image-id>          # Update cluster config to use custom AMI
    $0 update-script                      # Update S3 script (default: terraform/custom-image-script.sh)
    $0 help                               # Show this help

BUILD OPTIONS:
    -i, --image-id <name>        Custom image ID/name (default: auto-generated)
    -c, --config <file>          Image Builder config file (default: $CONFIG_FILE)
    -w, --wait                   Wait for build completion
    -t, --timeout <seconds>      Timeout for waiting (default: $TIMEOUT)

EXAMPLES:
    # Build an image and wait for completion
    $0 build --image-id my-custom-hpc-image --wait

    # Check status of a build
    $0 status my-custom-hpc-image

    # List all images
    $0 list

    # Update cluster config to use custom AMI
    $0 update-cluster my-custom-hpc-image

    # Update the S3 script with custom modifications
    $0 update-script /path/to/my-custom-script.sh
EOF
}

# Function to check if pcluster CLI is available
check_pcluster_cli() {
    if ! command -v pcluster &> /dev/null; then
        print_error "pcluster CLI is not installed or not in PATH"
        print_error "Install it with: pip install aws-parallelcluster"
        exit 1
    fi
}

# Function to generate a unique image ID
generate_image_id() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    echo "pcluster-custom-${timestamp}"
}

# Function to build custom image
build_image() {
    check_pcluster_cli

    if [[ -z "$IMAGE_ID" ]]; then
        IMAGE_ID=$(generate_image_id)
        print_status "Generated image ID: $IMAGE_ID"
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Config file not found: $CONFIG_FILE"
        print_error "Run 'terraform apply' to generate the config file"
        exit 1
    fi

    # Verify S3 script is accessible
    local s3_url=$(grep "Value: s3://" "$CONFIG_FILE" | awk '{print $2}')
    if [[ -n "$s3_url" ]]; then
        print_status "Verifying S3 script accessibility: $s3_url"
        if ! aws s3 ls "$s3_url" >/dev/null 2>&1; then
            print_error "Cannot access S3 script: $s3_url"
            print_error "Make sure AWS credentials are configured and S3 bucket exists"
            exit 1
        fi
    fi

    print_status "Building custom image: $IMAGE_ID"
    print_status "Using config file: $CONFIG_FILE"

    # Start the build
    if pcluster build-image --image-configuration "$CONFIG_FILE" --image-id "$IMAGE_ID" 2>/dev/null; then
        print_success "Image build started successfully!"
        print_status "Image ID: $IMAGE_ID"

        if [[ "$WAIT_FOR_COMPLETION" == "true" ]]; then
            wait_for_build "$IMAGE_ID"
        else
            print_status "Build is running in the background"
            print_status "Check status with: $0 status $IMAGE_ID"
        fi
    else
        print_error "Failed to start image build"
        exit 1
    fi
}

# Function to wait for build completion
wait_for_build() {
    local image_id="$1"
    local elapsed=0

    print_status "Waiting for build completion (timeout: ${TIMEOUT}s)..."

    while [[ $elapsed -lt $TIMEOUT ]]; do
        local status=$(pcluster describe-image --image-id "$image_id" --query 'imageBuildStatus' 2>/dev/null || echo "UNKNOWN")

        case "$status" in
            "BUILD_COMPLETE")
                print_success "Image build completed successfully!"
                local ami_id=$(pcluster describe-image --image-id "$image_id" --query 'ec2AmiInfo.amiId')
                print_success "Custom AMI ID: $ami_id"
                print_status "You can now use this AMI in your cluster configuration"
                return 0
                ;;
            "BUILD_FAILED")
                print_error "Image build failed!"
                print_error "Check the build logs for more details"
                return 1
                ;;
            "BUILD_IN_PROGRESS")
                print_status "Build in progress... (${elapsed}s elapsed)"
                ;;
            "UNKNOWN")
                print_warning "Could not determine build status"
                ;;
            *)
                print_status "Current status: $status (${elapsed}s elapsed)"
                ;;
        esac

        sleep 30
        elapsed=$((elapsed + 30))
    done

    print_warning "Build timeout reached. Check status manually with: $0 status $image_id"
}

# Function to check build status
check_status() {
    local image_id="$1"
    check_pcluster_cli

    print_status "Checking status for image: $image_id"

    if pcluster describe-image --image-id "$image_id" 2>/dev/null 1>/dev/null; then
        local status=$(pcluster describe-image --image-id "$image_id" --query 'imageBuildStatus' 2>/dev/null | tr -d '"')

        case "$status" in
            "BUILD_COMPLETE")
                local ami_id=$(pcluster describe-image --image-id "$image_id" --query 'ec2AmiInfo.amiId' )
                print_success "Build completed! AMI ID: $ami_id"
                ;;
            "BUILD_FAILED")
                print_error "Build failed! Check build logs for details"
                ;;
            "BUILD_IN_PROGRESS")
                print_status "Build is still in progress"
                ;;
            *)
                print_status "Current status: $status"
                ;;
        esac
    else
        print_error "Image not found: $image_id"
        exit 1
    fi
}

# Function to list all custom images
list_images() {
    check_pcluster_cli
    print_status "Listing all custom images..."
    pcluster list-images --image-status AVAILABLE 2>/dev/null
    print_status "Pending:"
    pcluster list-images --image-status PENDING 2>/dev/null
    print_status "Failed:"
    pcluster list-images --image-status FAILED 2>/dev/null
}

# Function to delete custom image
delete_image() {
    local image_id="$1"
    check_pcluster_cli

    print_warning "Deleting image: $image_id"
    read -p "Are you sure you want to delete this image? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if pcluster delete-image --image-id "$image_id"; then
            print_success "Image deletion started: $image_id"
        else
            print_error "Failed to delete image: $image_id"
            exit 1
        fi
    else
        print_status "Image deletion cancelled"
    fi
}

# Function to update cluster config with custom AMI
update_cluster_config() {
    local image_id="$1"
    check_pcluster_cli

    # Get the AMI ID from the image
    local ami_id=$(pcluster describe-image --image-id "$image_id" --query 'ec2AmiInfo.amiId' 2>/dev/null)

    if [[ -z "$ami_id" || "$ami_id" == "None" ]]; then
        print_error "Could not find AMI ID for image: $image_id"
        print_error "Make sure the image build completed successfully"
        exit 1
    fi

    local cluster_config="../cluster-config-generated.yaml"
    local backup_config="../cluster-config-generated.yaml.backup"

    if [[ ! -f "$cluster_config" ]]; then
        print_error "Cluster config file not found: $cluster_config"
        exit 1
    fi

    # Create backup
    cp "$cluster_config" "$backup_config"
    print_status "Created backup: $backup_config"

    # Update the cluster configuration
    if sed -i.tmp "s/# CustomAmi: .*/CustomAmi: $ami_id/" "$cluster_config" && \
       sed -i.tmp "s/Os: rhel9/# Os: rhel9/" "$cluster_config"; then
        rm -f "${cluster_config}.tmp"
        print_success "Updated cluster configuration with custom AMI: $ami_id"
        print_status "Modified file: $cluster_config"
        print_status "Backup available: $backup_config"
        print_status ""
        print_status "To use the custom image, deploy your cluster with:"
        print_status "pcluster create-cluster --cluster-name <name> --cluster-configuration $cluster_config"
    else
        rm -f "${cluster_config}.tmp"
        print_error "Failed to update cluster configuration"
        exit 1
    fi
}

# Function to update the S3 script
update_script() {
    local script_path="${1:-terraform/custom-image-script.sh}"

    if [[ ! -f "$script_path" ]]; then
        print_error "Script file not found: $script_path"
        exit 1
    fi

    print_status "Updating S3 script from: $script_path"

    # Get S3 details from Terraform outputs
    local s3_bucket=$(cd terraform && terraform output -raw imagebuilder_s3_bucket 2>/dev/null)

    if [[ -z "$s3_bucket" ]]; then
        print_error "Could not get S3 bucket name from Terraform outputs"
        print_error "Run 'terraform apply' first to create the infrastructure"
        exit 1
    fi

    # Upload the script
    if aws s3 cp "$script_path" "s3://$s3_bucket/custom-image-script.sh"; then
        print_success "Script uploaded to S3 successfully"
        print_status "S3 URL: s3://$s3_bucket/custom-image-script.sh"

        # Regenerate the imagebuilder config
        print_status "Regenerating Image Builder configuration..."
        if (cd terraform && terraform apply -auto-approve -target=local_file.imagebuilder_config); then
            print_success "Image Builder configuration updated"
        else
            print_warning "Failed to regenerate Image Builder config - you may need to run terraform apply"
        fi
    else
        print_error "Failed to upload script to S3"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        build)
            ACTION="build"
            shift
            ;;
        status)
            ACTION="status"
            IMAGE_ID="$2"
            shift 2
            ;;
        list)
            ACTION="list"
            shift
            ;;
        delete)
            ACTION="delete"
            IMAGE_ID="$2"
            shift 2
            ;;
        update-cluster)
            ACTION="update-cluster"
            IMAGE_ID="$2"
            shift 2
            ;;
        update-script)
            ACTION="update-script"
            shift
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        -i|--image-id)
            IMAGE_ID="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_COMPLETION=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute the requested action
case "$ACTION" in
    build)
        build_image
        ;;
    status)
        if [[ -z "$IMAGE_ID" ]]; then
            print_error "Image ID is required for status check"
            show_usage
            exit 1
        fi
        check_status "$IMAGE_ID"
        ;;
    list)
        list_images
        ;;
    delete)
        if [[ -z "$IMAGE_ID" ]]; then
            print_error "Image ID is required for deletion"
            show_usage
            exit 1
        fi
        delete_image "$IMAGE_ID"
        ;;
    update-cluster)
        if [[ -z "$IMAGE_ID" ]]; then
            print_error "Image ID is required for cluster config update"
            show_usage
            exit 1
        fi
        update_cluster_config "$IMAGE_ID"
        ;;
    update-script)
        update_script "$SCRIPT_PATH"
        ;;
    "")
        print_error "No action specified"
        show_usage
        exit 1
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac
