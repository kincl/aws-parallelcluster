# AWS ParallelCluster Configuration Generation

This guide explains how to generate AWS ParallelCluster configuration files automatically from your Terraform infrastructure.

## Overview

After deploying AWS infrastructure with Terraform, you need a `cluster-config.yaml` file that references the created resources (subnets, security groups, EFS, etc.). This repository provides multiple approaches to generate this configuration automatically.

## 🎯 Quick Start

The simplest approach is to use the provided makefile commands:

```bash
# Deploy infrastructure and generate configs
make apply

# Create a cluster
make create-cluster NAME=cluster1
```

That's it! The `make apply` command will run terraform to deploy the infrastructure and generate the configuration files. Then `make create-cluster NAME=cluster1` will create a cluster named "cluster1" using the generated configuration.

## 🏗️ Infrastructure Components

The generated configuration includes these Terraform-managed resources:

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **VPC** | Isolated network | 10.0.0.0/16 CIDR |
| **Public Subnet** | Head node | Internet access, Elastic IP |
| **Private Subnet** | Compute nodes | NAT Gateway access only |
| **Security Groups** | Network access | SSH, SLURM, NFS rules |
| **EFS File System** | Shared storage | Encrypted, multi-AZ |
| **NAT Gateway** | Compute internet | Package installations |

## 🖼️ Custom Image Building

You can build custom AMIs for your clusters using the makefile commands:

```bash
# List existing custom images
make image-list

# Build a custom image
make image-build ID=my-custom-image

# Check image build status
make image-status ID=my-custom-image

# Delete a custom image
make image-delete ID=my-custom-image
```

The image build process uses the auto-generated `imagebuilder-config-generated.yaml` file. You can optionally specify a custom configuration file with the `CONFIG` parameter:

```bash
make image-build ID=my-custom-image CONFIG=my-custom-imagebuilder-config.yaml
```

You can also wait for the build to complete by adding the `WAIT=true` parameter:

```bash
make image-build ID=my-custom-image WAIT=true
```

### Using Custom Images with Clusters

Once your custom image is built, you can reference it in your cluster configuration by updating the `Image` section in the generated cluster configuration file:

```yaml
Image:
  CustomAmi: ami-0123456789abcdef0  # Your custom AMI ID
```

Or set it in your Terraform variables to have it automatically included in the generated configuration.

## 📋 Generated Cluster Configuration

The auto-generated `cluster-config.yaml` includes:

### Infrastructure Mapping
```yaml
Region: us-east-2                    # From terraform
HeadNode:
  Networking:
    SubnetId: subnet-xyz123          # From terraform output
    SecurityGroups: [sg-abc456]      # From terraform output
Scheduling:
  SlurmQueues:
    - Networking:
        SubnetIds: [subnet-def789]   # From terraform output
SharedStorage:
  - EfsSettings:
      FileSystemId: fs-ghi012        # From terraform output
```

### Default Cluster Setup
- **Head Node**: t3.medium with Elastic IP
- **Compute Queues**:
  - `debug`: c5.xlarge instances (0-5 nodes)
- **Storage**: EFS mounted at `/shared`

## ⚙️ Customization Options

### 1. Pre-Generation (Terraform Variables)

Customize infrastructure before deployment in `terraform.tfvars`:

```hcl
# Network customization
vpc_cidr = "172.16.0.0/16"
head_node_subnet_cidr = "172.16.1.0/24"

# Security customization
ssh_allowed_cidr_blocks = ["203.0.113.0/24"]  # Your IP range
ssh_key_name = "my-aws-keypair"

# EFS customization
efs_performance_mode = "maxIO"
efs_throughput_mode = "provisioned"
```

### 2. Post-Generation (Cluster Config)

Modify the generated `cluster-config-generated.yaml`:

```yaml
# Change head node instance type
HeadNode:
  InstanceType: t3.medium

# Add more queues
SlurmQueues:
  - Name: gpu
    ComputeResources:
    - Name: p3xlarge
      InstanceType: p3.xlarge
      MinCount: 0
      MaxCount: 2

# Use custom AMI
Image:
  CustomAmi: ami-0123456789abcdef0
```

## 🔧 Available Makefile Commands

```bash
# Show all available commands
make help

# Setup initial configuration
make setup

# Check prerequisites
make check-prereqs

# Deploy infrastructure
make apply

# Generate configuration files
make generate-config

# Validate configuration
make validate-config

# Create a cluster
make create-cluster NAME=mycluster

# SSH to cluster head node
make ssh NAME=mycluster

# Delete a cluster
make delete-cluster NAME=mycluster

# Show infrastructure and cluster status
make status

# Show Terraform outputs
make outputs

# Destroy all infrastructure
make destroy
```

## 🚀 Deployment Workflow

### Complete Setup Process:

1. **Configure Terraform**:
   ```bash
   make setup
   vim terraform/terraform.tfvars  # Edit your settings
   ```

2. **Deploy Infrastructure and Generate Config**:
   ```bash
   make apply
   ```

3. **Validate Configuration**:
   ```bash
   make validate-config
   ```

4. **Deploy Cluster**:
   ```bash
   make create-cluster NAME=my-research-cluster
   ```

5. **Monitor Cluster Status**:
   ```bash
   make status
   ```

6. **Connect to Cluster**:
   ```bash
   make ssh NAME=my-research-cluster
   ```

## 🔍 Troubleshooting

### Common Issues and Solutions:

**❌ "Terraform state file not found"**
```bash
# Solution: Deploy infrastructure first
make apply
```

**❌ "Could not retrieve subnet ID"**
```bash
# Check Terraform outputs
make outputs
```

**❌ "SSH key 'xyz' does not exist"**
```bash
# List available keys
aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName'

# Update SSH key in terraform.tfvars and regenerate
make generate-config
```

**❌ "Invalid cluster configuration"**
```bash
# Validate before deployment
make validate-config
```

## 🔐 Security Best Practices

### Network Security:
- ✅ Restrict SSH access to your IP range
- ✅ Use private subnets for compute nodes
- ✅ Enable EFS encryption
- ✅ Use security groups for least privilege

### Example secure configuration:
```hcl
# terraform.tfvars
ssh_allowed_cidr_blocks = ["203.0.113.0/24"]  # Your office IP range
efs_encrypted = true
```

## 🎛️ Advanced Configurations

### Custom Instance Types:
```yaml
# In cluster-config-generated.yaml
SlurmQueues:
  - Name: memory-optimized
    ComputeResources:
    - Name: r5xlarge
      InstanceType: r5.xlarge
      MinCount: 0
      MaxCount: 10
```

### Spot Instances:
```yaml
ComputeResources:
- Name: spot-instances
  InstanceType: c5.xlarge
  MinCount: 0
  MaxCount: 20
  SpotPrice: 0.05
```

## 🔄 Updates and Maintenance

### Updating Infrastructure:
1. Modify `terraform.tfvars`
2. Run `make apply`
3. Regenerate cluster config if needed with `make generate-config`

### Updating Cluster Configuration:
1. Modify the generated YAML file
2. Update existing cluster: `pcluster update-cluster`
3. Or create new cluster with new config

## 📚 Additional Resources

- [AWS ParallelCluster User Guide](https://docs.aws.amazon.com/parallelcluster/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
