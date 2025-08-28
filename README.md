# AWS ParallelCluster Configuration Generation

This guide explains how to generate AWS ParallelCluster configuration files automatically from your Terraform infrastructure.

## Overview

After deploying AWS infrastructure with Terraform, you need a `cluster-config.yaml` file that references the created resources (subnets, security groups, EFS, etc.). This repository provides multiple approaches to generate this configuration automatically.

## 🎯 Quick Start

### Method 1: Automatic Generation with Terraform (Recommended)

The simplest approach - the cluster configuration is generated automatically when you apply Terraform:

```bash
cd terraform
terraform init
terraform apply
```

✅ **Output**: `cluster-config-generated.yaml` is created automatically

### Manual Regeneration

If you need to regenerate just the configuration file:

```bash
make generate-config
```

✅ **Output**: `cluster-config-generated.yaml` is updated

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

## 🔧 Available Scripts

### Terraform Template Generation
- ✅ Automatic generation during `terraform apply`
- ✅ Consistent with infrastructure state
- ✅ Support for custom AMI configuration

```bash
make generate-config
```

## 📁 File Structure

```
aws-parallelcluster/
├── terraform/
│   ├── main.tf                          # Infrastructure definition
│   ├── outputs.tf                       # Terraform outputs
│   ├── variables.tf                     # Configurable variables
│   ├── terraform.tfvars.example         # Example configuration
│   └── cluster-config-template.yaml     # Template for generation
├── scripts/
│   ├── build-custom-image.sh            # Custom image builder script
│   └── README.md                        # Script documentation
└── pcluster/
    ├── cluster-config.yaml              # Original example
    └── cluster-config-generated.yaml    # Auto-generated (created)
```

## 🚀 Deployment Workflow

### Complete Setup Process:

1. **Configure Terraform**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars  # Edit your settings
   ```

2. **Deploy Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Validate Configuration**:
   ```bash
   pcluster create-cluster \
     --cluster-name my-research-cluster \
     --cluster-configuration ../pcluster/cluster-config-generated.yaml \
     --dryrun true
   ```

4. **Deploy Cluster**:
   ```bash
   pcluster create-cluster \
     --cluster-name my-research-cluster \
     --cluster-configuration cluster-config-generated.yaml
   ```

## 🔍 Troubleshooting

### Common Issues and Solutions:

**❌ "Terraform state file not found"**
```bash
# Solution: Deploy infrastructure first
terraform apply
```

**❌ "Could not retrieve subnet ID"**
```bash
# Check Terraform outputs
terraform output
terraform output head_node_subnet_id
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
pcluster validate-cluster-configuration \
  --cluster-configuration cluster-config-generated.yaml
```

### Debug Commands:

```bash
# Check all Terraform outputs
cd terraform && terraform output

# Check specific resource
terraform output efs_file_system_id

# Test AWS connectivity
aws sts get-caller-identity

# Validate cluster config
pcluster validate-cluster-configuration \
  --cluster-configuration cluster-config-generated.yaml
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
2. Run `terraform plan` to review changes
3. Run `terraform apply`
4. Regenerate cluster config if needed

### Updating Cluster Configuration:
1. Modify the generated YAML file
2. Update existing cluster: `pcluster update-cluster`
3. Or create new cluster with new config

## 📚 Additional Resources

- [AWS ParallelCluster User Guide](https://docs.aws.amazon.com/parallelcluster/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
