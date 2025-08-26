# AWS ParallelCluster Image Builder Guide

This guide explains how to build and use custom Amazon Machine Images (AMIs) for AWS ParallelCluster using the automatically generated Image Builder configuration.

## Overview

The Terraform configuration automatically creates:
- **S3 bucket** for storing custom build scripts
- **Image Builder configuration** with proper ParallelCluster RHEL9 parent image
- **Helper scripts** for managing the build process
- **Integration** with existing cluster infrastructure

## Quick Start

### 1. Build Your First Custom Image

```bash
# Build with auto-generated name and wait for completion
./scripts/build-custom-image.sh build --wait

# Or build with custom name
./scripts/build-custom-image.sh build --image-id my-hpc-image --wait
```

### 2. Check Build Status

```bash
# Check status of a specific image
./scripts/build-custom-image.sh status my-hpc-image

# List all custom images
./scripts/build-custom-image.sh list
```

### 3. Use Custom Image in Cluster

```bash
# Update cluster config to use custom AMI
./scripts/build-custom-image.sh update-cluster my-hpc-image

# Deploy cluster with custom image
pcluster create-cluster --cluster-name my-cluster --cluster-configuration cluster-config-generated.yaml
```

## Default Custom Image Features

The default build script installs:

### System Packages
- **Development Tools** group (gcc, make, etc.)
- **Utilities**: htop, iotop, git, wget, curl, vim, tmux, screen, tree
- **Network Tools**: nc, rsync, tcpdump
- **System Tools**: lsof, strace, unzip, bzip2

### Python Environment
- **Python 3** with pip, venv, wheel
- **Scientific Libraries**: numpy, scipy, matplotlib, pandas
- **Interactive Tools**: jupyter, ipython
- **Machine Learning**: scikit-learn
- **Visualization**: seaborn, plotly

### HPC Libraries
- **OpenMPI** development libraries
- **LAPACK/BLAS** for linear algebra
- **FFTW** for Fast Fourier Transforms
- **HDF5** for data storage

### Directory Structure
- `/shared/apps` - Custom application installations
- `/shared/data` - Shared data storage
- `/shared/scripts` - Shared utility scripts
- `/shared/modules` - Environment module files
- `/shared/templates` - Job submission templates

### Environment Setup
- **Global aliases** and environment variables
- **Environment Modules** support
- **Custom vim configuration**
- **Sample job templates**

## Customizing the Build Script

### Method 1: Edit Default Script

```bash
# Edit the default script
vim terraform/custom-image-script.sh

# Apply changes (uploads to S3)
cd terraform && terraform apply

# Build with updated script
../scripts/build-custom-image.sh build --image-id updated-image --wait
```

### Method 2: Use Custom Script

```bash
# Create your custom script
cat > my-custom-script.sh << 'EOF'
#!/bin/bash
echo "Installing my custom software..."
sudo dnf install -y custom-package
# Add your custom installation steps
EOF

# Update S3 with your script
./scripts/build-custom-image.sh update-script my-custom-script.sh

# Build with custom script
./scripts/build-custom-image.sh build --image-id my-custom-image --wait
```

## Common Customization Examples

### Installing Conda/Miniconda

Add to your custom script:
```bash
# Install Miniconda
wget -O /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash /tmp/miniconda.sh -b -p /shared/apps/miniconda3
rm /tmp/miniconda.sh

# Add to global PATH
echo 'export PATH="/shared/apps/miniconda3/bin:$PATH"' >> /etc/profile.d/conda.sh
```

### Installing Intel oneAPI

Add to your custom script:
```bash
# Install Intel oneAPI Base Toolkit
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo dnf update
sudo dnf install -y intel-basekit
```

### Installing Docker

Add to your custom script:
```bash
# Install Docker
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker

# Add users to docker group (they need to log out/in)
sudo usermod -aG docker ec2-user
```

### Installing Singularity/Apptainer

Add to your custom script:
```bash
# Install Apptainer (Singularity)
sudo dnf install -y epel-release
sudo dnf install -y apptainer
```

## Build Process Details

### Build Timeline
- **Typical Duration**: 30-60 minutes
- **Instance Type**: c5.xlarge (configurable)
- **Root Volume**: 35GB (configurable)

### Build Steps
1. **Launch**: EC2 instance in your VPC subnet
2. **Download**: Base ParallelCluster RHEL9 AMI
3. **Execute**: Your custom script from S3
4. **Create**: New AMI with modifications
5. **Cleanup**: Terminate build instance

### Monitoring Build Progress

```bash
# Watch build status
watch -n 30 "./scripts/build-custom-image.sh status my-image-id"

# View detailed CloudWatch logs
aws logs describe-log-streams \
  --log-group-name "/aws/imagebuilder/instance" \
  --query 'logStreams[0].logStreamName' \
  --output text

aws logs get-log-events \
  --log-group-name "/aws/imagebuilder/instance" \
  --log-stream-name <stream-name>
```

## Troubleshooting

### Build Failures

1. **Check Script Syntax**
   ```bash
   # Test script locally
   bash -n terraform/custom-image-script.sh
   ```

2. **Verify S3 Access**
   ```bash
   # Check if script is accessible
   aws s3 ls s3://$(cd terraform && terraform output -raw imagebuilder_s3_bucket)/
   ```

3. **Review Build Logs**
   ```bash
   # Get build details
   pcluster describe-image --image-id my-image-id
   
   # Check CloudWatch logs for errors
   aws logs filter-log-events \
     --log-group-name "/aws/imagebuilder/instance" \
     --filter-pattern "ERROR"
   ```

### Network Issues

- Ensure subnet has internet access for package downloads
- Verify security group allows outbound traffic
- Check NAT Gateway is functioning for private subnets

### Permission Issues

- Verify IAM permissions for EC2 Image Builder
- Check S3 bucket permissions
- Ensure ParallelCluster service role exists

## Best Practices

### Script Development
1. **Test Locally**: Use EC2 instance to test script components
2. **Error Handling**: Add proper error checking in scripts
3. **Logging**: Include verbose output for debugging
4. **Idempotent**: Make scripts re-runnable safely

### Security
1. **Minimal Permissions**: Only install necessary software
2. **Update Packages**: Keep base packages updated
3. **Remove Secrets**: Don't embed credentials in scripts
4. **Validate Sources**: Verify download sources

### Performance
1. **Package Cache**: Clean package caches to reduce image size
2. **Parallel Installs**: Use parallel package installation where possible
3. **Layer Efficiently**: Group related installations together

### Version Control
1. **Script Versioning**: Keep scripts in version control
2. **AMI Tagging**: Use descriptive tags for AMIs
3. **Build Documentation**: Document what each build includes

## Advanced Topics

### Using Multiple Scripts

Create a main script that calls others:
```bash
#!/bin/bash
# Main installation script

# Base HPC tools
bash /shared/scripts/install-hpc-tools.sh

# Domain-specific software
bash /shared/scripts/install-bioinformatics.sh
bash /shared/scripts/install-ml-tools.sh
```

### Environment Modules Setup

```bash
# Create module files
mkdir -p /shared/modules/modulefiles/apps
cat << 'EOF' > /shared/modules/modulefiles/apps/custom-app
#%Module1.0
proc ModulesHelp { } {
    puts stderr "Custom application v1.0"
}
module-whatis "Custom application"
prepend-path PATH /shared/apps/custom-app/bin
EOF
```

### Container Integration

```bash
# Pre-pull common containers
singularity pull /shared/containers/ubuntu.sif docker://ubuntu:20.04
singularity pull /shared/containers/python.sif docker://python:3.9
```

## Cost Optimization

### Build Efficiency
- Use faster instance types for complex builds
- Build during off-peak hours
- Delete failed/unused AMIs promptly

### Storage Optimization
- Clean package caches: `sudo dnf clean all`
- Remove build artifacts
- Compress large files in shared directories

### AMI Management
```bash
# List old AMIs
aws ec2 describe-images --owners self --query 'Images[?CreationDate<`2024-01-01`]'

# Automate cleanup with lifecycle policies
./scripts/build-custom-image.sh delete old-image-id
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build Custom ParallelCluster AMI
on:
  push:
    paths:
      - 'terraform/custom-image-script.sh'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-2
      
      - name: Update S3 script
        run: |
          ./scripts/build-custom-image.sh update-script terraform/custom-image-script.sh
      
      - name: Build AMI
        run: |
          ./scripts/build-custom-image.sh build --image-id "build-${{ github.sha }}" --wait
```

## Support and Resources

### Getting Help
- Check CloudWatch logs for build details
- Review AWS ParallelCluster documentation
- Validate script syntax before building

### Useful Commands Reference
```bash
# Build management
./scripts/build-custom-image.sh build --image-id <name> --wait
./scripts/build-custom-image.sh status <image-id>
./scripts/build-custom-image.sh list
./scripts/build-custom-image.sh delete <image-id>

# Configuration management
./scripts/build-custom-image.sh update-script <script-path>
./scripts/build-custom-image.sh update-cluster <image-id>

# AWS CLI helpers
aws s3 ls s3://$(terraform output -raw imagebuilder_s3_bucket)/
pcluster describe-image --image-id <image-id>
pcluster list-images --image-status BUILD_COMPLETE
```

### File Locations
- **Build Script**: `terraform/custom-image-script.sh`
- **Generated Config**: `imagebuilder-config-generated.yaml`
- **Helper Script**: `scripts/build-custom-image.sh`
- **S3 Bucket**: Auto-generated with random suffix