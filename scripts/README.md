# AWS ParallelCluster Configuration Generator

This directory contains scripts and configuration templates for AWS ParallelCluster infrastructure management.

## Overview

The ParallelCluster configuration is automatically generated using Terraform's `templatefile()` function. When you run `terraform apply`, it processes the `cluster-config-template.yaml` template with actual infrastructure values and creates the cluster configuration file.

## Prerequisites

- Terraform infrastructure must be deployed first (`terraform apply` completed successfully)
- AWS CLI configured with appropriate permissions

## Configuration Generation

### Terraform Template Approach (Recommended)

The cluster configuration is automatically generated as part of the Terraform deployment process.

**How it works:**

1. The `terraform/cluster-config-template.yaml` file contains a template with placeholders
2. During `terraform apply`, the template is processed with actual resource IDs
3. The generated file is saved as `cluster-config-generated.yaml` in the project root

**Usage:**

From the project root:
```bash
# Generate configuration as part of full deployment
make apply

# Or generate just the configuration file
make generate-config
```

This runs `terraform apply -auto-approve -target=local_file.cluster_config` to generate only the cluster configuration file.

## Custom AMI Support

You can optionally use a custom AMI by setting the `custom_ami` variable in `terraform/terraform.tfvars`:

```hcl
# Use default ParallelCluster AMI (recommended for most users)
custom_ami = ""

# Or specify a custom AMI ID
custom_ami = "ami-0123456789abcdef0"
```

When `custom_ami` is set to a non-empty value, the generated cluster configuration will include:
```yaml
Image:
  Os: rhel9
  CustomAmi: ami-0123456789abcdef0
```

When `custom_ami` is empty or unset, it will only include:
```yaml
Image:
  Os: rhel9
```

## Configuration Details

The generated cluster configuration includes:

### Infrastructure Components:
- **Region**: AWS region where infrastructure is deployed
- **Head Node Subnet**: Public subnet for the head node with Elastic IP
- **Compute Subnet**: Private subnet for compute nodes
- **Security Groups**: Configured for SLURM communication and SSH access
- **EFS File System**: Shared storage mounted at `/shared`

### Default Cluster Configuration:
- **Image**: RHEL 9 (with optional custom AMI support)
- **Head Node**: m5a.large instance with Elastic IP
- **Compute Queues**:
  - `debug`: c7i-flex.large instances (0-5 nodes)
  - `standard`: c5.xlarge instances (0-5 nodes)
  - `gpu`: g4dn.4xlarge instances (0-5 nodes)
- **Shared Storage**: EFS mounted at `/shared`

## Customization

After generating the configuration file, you can customize:

1. **Instance Types**: Modify the template or edit the generated file
2. **Queue Configuration**: Add/remove queues, change scaling limits
3. **Custom AMI**: Set `custom_ami` variable in `terraform.tfvars`
4. **Operating System**: Modify the `Os` field in the template
5. **Additional Storage**: Add more EFS or FSx storage configurations

## Validation

Validate your configuration before deploying:

```bash
make validate-config
```

This runs: `pcluster create-cluster --cluster-name test --cluster-configuration cluster-config-generated.yaml --dryrun true`

## Deployment

Deploy your cluster using the generated configuration:

```bash
make create-cluster CLUSTER_NAME=my-cluster
```

Or manually:
```bash
pcluster create-cluster \
  --cluster-name my-parallelcluster \
  --cluster-configuration cluster-config-generated.yaml
```

## Other Scripts

### build-custom-image.sh

Script for building custom ParallelCluster images using Image Builder. This creates AMIs with pre-installed software and configurations.

Usage:
```bash
cd scripts
./build-custom-image.sh
```

## Troubleshooting

### Common Issues:

1. **"cluster-config-generated.yaml not found"**
   - Run `make generate-config` to create the configuration file
   - Ensure Terraform infrastructure is deployed first

2. **"Terraform state file not found"**
   - Run `make apply` to deploy the infrastructure first

3. **Custom AMI not appearing in config**
   - Ensure `custom_ami` is set in `terraform/terraform.tfvars`
   - Run `make generate-config` after updating the variable

### Debug Commands:

```bash
# Check Terraform outputs
make outputs

# Check infrastructure status
make status

# Validate configuration
make validate-config

# Generate fresh configuration
make generate-config
```

## File Structure

```
scripts/
├── README.md                    # This file
├── build-custom-image.sh        # Custom image builder script
terraform/
├── cluster-config-template.yaml # Terraform template file
└── main.tf                     # Includes local_file resource for config generation
```

## Security Notes

- Review and restrict SSH access CIDR blocks in production
- Consider using custom AMIs with security hardening  
- Update SSH key names to match your environment
- Review security group rules for your specific requirements
- The generated configuration uses RHEL 9 by default

## Next Steps

1. Set `custom_ami` in `terraform.tfvars` if using a custom image
2. Run `make deploy` for complete infrastructure and config generation
3. Customize the generated configuration as needed
4. Validate with `make validate-config`
5. Deploy with `make create-cluster CLUSTER_NAME=your-cluster-name`
6. Connect with `make ssh-cluster CLUSTER_NAME=your-cluster-name`
