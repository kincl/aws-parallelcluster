# AWS ParallelCluster Configuration Generator

This directory contains scripts and templates to automatically generate AWS ParallelCluster configuration files from Terraform infrastructure outputs.

## Overview

After deploying the infrastructure using Terraform, you need to generate a `cluster-config.yaml` file that references the created resources. This directory provides two approaches:

1. **Terraform Template Approach**: Automatically generates the config file as part of `terraform apply`
2. **Shell Script Approach**: Manually generates the config file from Terraform outputs

## Prerequisites

- Terraform infrastructure must be deployed first (`terraform apply` completed successfully)
- AWS CLI configured with appropriate permissions
- For shell script approach: `jq` command-line tool (for the full-featured script)

## Method 1: Terraform Template (Automatic)

The Terraform configuration includes a `local_file` resource that automatically generates the cluster configuration file.

### How it works:

1. The `cluster-config-template.yaml` file contains a template with placeholders
2. During `terraform apply`, the template is processed with actual resource IDs
3. The generated file is saved as `../pcluster/cluster-config-generated.yaml`

### Usage:

```bash
cd terraform
terraform apply
```

The cluster configuration will be automatically generated at `pcluster/cluster-config-generated.yaml`.

## Method 2: Shell Scripts (Manual)

Two shell scripts are provided for manual generation:

### Full-Featured Script (`generate-cluster-config.sh`)

Requires `jq` for JSON parsing and provides comprehensive error checking.

```bash
cd scripts
./generate-cluster-config.sh [OPTIONS]
```

**Options:**
- `-t, --terraform-dir DIR`: Path to Terraform directory (default: ../terraform)
- `-o, --output FILE`: Output file path (default: ../pcluster/cluster-config-generated.yaml)
- `-k, --ssh-key KEY`: SSH key name (default: jkincl)
- `-h, --help`: Show help message

**Example:**
```bash
./generate-cluster-config.sh -k my-ssh-key -o ~/my-cluster-config.yaml
```

### Simple Script (`generate-cluster-config-simple.sh`)

Does not require `jq` and uses basic text processing.

```bash
cd scripts
./generate-cluster-config-simple.sh [OPTIONS]
```

Same options as the full-featured script.

## Configuration Details

The generated cluster configuration includes:

### Infrastructure Components:
- **Region**: AWS region where infrastructure is deployed
- **Head Node Subnet**: Public subnet for the head node
- **Compute Subnet**: Private subnet for compute nodes
- **Security Groups**: Configured for SLURM and SSH access
- **EFS File System**: Shared storage mounted at `/shared`

### Cluster Configuration:
- **Image**: CentOS 7 (can be customized)
- **Head Node**: t2.micro instance with Elastic IP
- **Compute Queues**:
  - `micro`: t2.micro instances (0-10 nodes)
  - `xlarge`: c5.xlarge instances (0-5 nodes)
- **Shared Storage**: EFS mounted at `/shared`

## Customization

After generating the configuration file, you can customize:

1. **Instance Types**: Change instance types for head node or compute nodes
2. **Queue Configuration**: Modify queue names, instance types, or scaling limits
3. **Operating System**: Change from CentOS 7 to other supported OSes
4. **Custom AMI**: Uncomment and specify a custom AMI ID
5. **Additional Queues**: Add more compute queues with different configurations

## Validation

Before deploying the cluster, validate your configuration:

```bash
pcluster validate-cluster-configuration --cluster-configuration cluster-config-generated.yaml
```

## Deployment

Deploy your cluster using the generated configuration:

```bash
pcluster create-cluster \
  --cluster-name my-parallelcluster \
  --cluster-configuration cluster-config-generated.yaml
```

## Troubleshooting

### Common Issues:

1. **"Terraform state file not found"**
   - Ensure you've run `terraform apply` successfully
   - Check that you're in the correct directory

2. **"Could not retrieve ... from Terraform outputs"**
   - Verify Terraform resources were created successfully
   - Run `terraform output` to check available outputs

3. **"SSH key not found"**
   - Ensure the SSH key exists in your AWS account
   - Update the key name in the script or configuration

4. **Region mismatch**
   - Ensure your AWS CLI region matches the Terraform deployment region

### Debug Commands:

```bash
# Check Terraform outputs
cd terraform
terraform output

# Check specific output
terraform output head_node_subnet_id

# Validate cluster configuration
pcluster validate-cluster-configuration --cluster-configuration cluster-config-generated.yaml
```

## File Structure

```
scripts/
├── README.md                           # This file
├── generate-cluster-config.sh          # Full-featured generation script
├── generate-cluster-config-simple.sh   # Simple generation script
└── ../terraform/
    └── cluster-config-template.yaml    # Terraform template file
```

## Security Notes

- Review and restrict SSH access CIDR blocks in production
- Consider using custom AMIs with security hardening
- Update SSH key names to match your environment
- Review security group rules for your specific requirements

## Next Steps

1. Generate or review your cluster configuration
2. Customize instance types and scaling parameters as needed
3. Validate the configuration using `pcluster validate-cluster-configuration`
4. Deploy the cluster using `pcluster create-cluster`
5. Monitor cluster creation and troubleshoot any issues