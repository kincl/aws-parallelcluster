# AWS ParallelCluster Infrastructure with Terraform

This Terraform configuration creates the base infrastructure needed to deploy AWS ParallelCluster, including networking, security groups, shared storage, and custom AMI building via Image Builder.

## What This Creates

### Networking Infrastructure
- **VPC** with DNS hostnames and DNS support enabled
- **Public Subnet** for the head node with internet gateway access (AZ: us-east-2a)
- **Private Subnet** for compute nodes with NAT gateway for outbound internet access (AZ: us-east-2b)
- **Internet Gateway** for public internet access
- **NAT Gateway** with Elastic IP for private subnet internet access
- **Route Tables** with appropriate routing for public and private subnets

### Security
- **Security Group for ParallelCluster nodes** with SSH access and internal cluster communication
- **Security Group for EFS** allowing NFS traffic from cluster subnets

### Storage
- **EFS File System** with encryption enabled
- **EFS Mount Targets** in both availability zones (one per AZ as required by AWS)
- **EFS Access Point** for the `/shared` directory with proper permissions

### Custom Image Building
- **Generated Image Builder Configuration** for creating custom ParallelCluster AMIs
- **Automatic ParentImage Discovery** using the latest ParallelCluster RHEL9 AMI
- **Configurable Build Settings** for instance type, packages, and custom scripts

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **AWS permissions** to create VPC, EC2, and EFS resources

## Usage

### 1. Clone and Navigate
```bash
cd aws-parallelcluster/terraform
```

### 2. Configure Variables
Copy the example variables file and customize it:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to match your requirements:
- Set your desired AWS region
- Choose appropriate CIDR blocks for your VPC and subnets
- Configure EFS settings based on your performance needs
- Restrict SSH access to your IP range for security

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan the Deployment
```bash
terraform plan
```

### 5. Apply the Configuration
```bash
terraform apply
```

### 6. Get Output Values
After successful deployment, you can view the created resource IDs:
```bash
terraform output
```

## Important Outputs

The following outputs are specifically needed for your ParallelCluster configuration:

- `head_node_subnet_id` - Use this for the HeadNode SubnetId
- `compute_subnet_id` - Use this for the compute queues SubnetIds
- `efs_file_system_id` - Use this for the SharedStorage EfsSettings FileSystemId
- `pcluster_security_group_id` - Additional security group for the cluster nodes
- `pcluster_parent_image_id` - AMI ID of the ParallelCluster RHEL9 parent image for Image Builder

## Generated Configurations

After running Terraform, two configuration files are automatically generated in the project root:

1. **`cluster-config-generated.yaml`** - Ready-to-use ParallelCluster configuration
2. **`imagebuilder-config-generated.yaml`** - Custom AMI build configuration

## Using the Generated Configurations

### ParallelCluster Deployment
Use the generated cluster configuration directly:
```bash
pcluster create-cluster --cluster-name my-cluster --cluster-configuration cluster-config-generated.yaml
```

### Building a Custom AMI (Optional)
If you need a custom AMI with additional software:

1. **Build the custom image**:
```bash
pcluster build-image --image-configuration imagebuilder-config-generated.yaml --image-id my-custom-image
```

2. **Wait for the build to complete** (usually 30-60 minutes):
```bash
pcluster describe-image --image-id my-custom-image
```

3. **Update your cluster config** to use the custom AMI:
```yaml
Image:
  # CustomAmi: ami-xxxxxxxxx  # Replace with your custom AMI ID
```

### Manual Configuration Updates
If you prefer to manually update your `cluster-config.yaml` with the new resource IDs:

```yaml
HeadNode:
  Networking:
    SubnetId: <head_node_subnet_id>
    # Add the security group if needed
    AdditionalSecurityGroups:
      - <pcluster_security_group_id>

Scheduling:
  SlurmQueues:
  - Name: micro
    Networking:
      SubnetIds:
      - <compute_subnet_id>
  - Name: xlarge
    Networking:
      SubnetIds:
      - <compute_subnet_id>

SharedStorage:
  - MountDir: /shared
    Name: shared-efs
    StorageType: Efs
    EfsSettings:
      FileSystemId: <efs_file_system_id>
```

## Customization Options

### Network Configuration
- **Single-AZ Setup**: Head node and compute subnets are placed in the same availability zone (us-east-2a) for optimal performance
- Modify CIDR blocks to fit your network architecture
- Add additional subnets for multi-AZ deployment
- Adjust security group rules based on your security requirements

### Image Builder Configuration
- **Instance Type**: Default `c5.xlarge`, configurable via `imagebuilder_instance_type`
- **Root Volume Size**: Default 35GB, configurable via `imagebuilder_root_volume_size`
- **S3 Script Storage**: Custom build script automatically uploaded to S3
- **Script Customization**: Edit `terraform/custom-image-script.sh` and re-run `terraform apply`

The Image Builder configuration uses an S3-stored script for maximum flexibility:

1. **Default Script**: Installs development tools, Python packages, HPC utilities
2. **Custom Modifications**: Edit `custom-image-script.sh` in the terraform directory
3. **Automatic Upload**: Script is uploaded to S3 bucket during terraform apply
4. **Version Control**: S3 bucket has versioning enabled for script history

Example workflow for custom scripts:
```bash
# Edit the custom script
vim terraform/custom-image-script.sh

# Apply changes (uploads new script to S3)
terraform apply

# Or use the helper script
./scripts/build-custom-image.sh update-script /path/to/my-script.sh
```

Example terraform.tfvars customization:
```hcl
imagebuilder_instance_type = "c5.2xlarge"
imagebuilder_root_volume_size = 50
```

### EFS Configuration
- **Performance Mode**: Choose between `generalPurpose` (default) or `maxIO` for higher IOPS
- **Throughput Mode**: Choose between `bursting` (default) or `provisioned` for guaranteed throughput
- **Encryption**: Enabled by default, can be disabled if not required

### Security
- Restrict SSH access by updating `ssh_allowed_cidr_blocks`
- Add additional security group rules as needed
- Consider using AWS Systems Manager Session Manager instead of direct SSH

## Cost Considerations

- **NAT Gateway**: Charges for data processing and hourly usage
- **EFS**: Charges based on storage used and throughput mode
- **Elastic IP**: Free when associated with running instances

## Security Best Practices

1. **Restrict SSH Access**: Don't use `0.0.0.0/0` in production
2. **Use Private Subnets**: Compute nodes are placed in private subnets by default
3. **Enable EFS Encryption**: Enabled by default in this configuration
4. **Regular Updates**: Keep Terraform and AWS provider versions updated
5. **Custom AMI Security**: Review and validate any custom scripts before building images
6. **S3 Script Security**: S3 bucket has public access blocked and encryption enabled
7. **Script Validation**: Always test custom scripts in a dev environment first

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

**Warning**: This will permanently delete all created resources. Make sure you have backups of any important data stored on EFS.

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Ensure your AWS credentials have permissions to create VPC, EC2, EFS, and IAM resources
2. **Region Availability**: Some instance types may not be available in all regions
3. **CIDR Conflicts**: Ensure your chosen CIDR blocks don't conflict with existing networks
4. **EFS Mount Targets**: AWS allows only one EFS mount target per availability zone
5. **Image Builder Failures**: Check build logs in CloudWatch, ensure subnet has internet access
6. **AMI Permissions**: Custom AMIs are private by default, share appropriately if needed

### Useful Commands

```bash
# Check current state
terraform show

# Import existing resources (if needed)
terraform import aws_vpc.pcluster_vpc vpc-xxxxxxxxx

# Refresh state
terraform refresh

# Check Image Builder status
pcluster list-images
pcluster describe-image --image-id <image-id>

# Monitor build progress
aws logs describe-log-groups --log-group-name-prefix /aws/imagebuilder

# S3 script management
aws s3 ls s3://$(terraform output -raw imagebuilder_s3_bucket)/
aws s3 cp custom-image-script.sh s3://$(terraform output -raw imagebuilder_s3_bucket)/

# Use helper script for common operations
./scripts/build-custom-image.sh build --image-id my-image --wait
./scripts/build-custom-image.sh update-script my-custom-script.sh
```

## Support

For issues specific to this Terraform configuration, check:
1. Terraform logs and error messages
2. AWS CloudTrail for API call details
3. AWS documentation for service limits and requirements