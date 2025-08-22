# AWS ParallelCluster Infrastructure with Terraform

This Terraform configuration creates the base infrastructure needed to deploy AWS ParallelCluster, including networking, security groups, and shared storage.

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

## Updating Your ParallelCluster Configuration

After running this Terraform configuration, update your `cluster-config.yaml` with the new resource IDs:

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
- **Multi-AZ Setup**: Head node and compute subnets are placed in different availability zones (us-east-2a and us-east-2b) to support EFS mount targets (AWS requires one mount target per AZ)
- Modify CIDR blocks to fit your network architecture
- Add additional subnets for multi-AZ deployment
- Adjust security group rules based on your security requirements

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

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

**Warning**: This will permanently delete all created resources. Make sure you have backups of any important data stored on EFS.

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Ensure your AWS credentials have permissions to create VPC, EC2, and EFS resources
2. **Region Availability**: Some instance types may not be available in all regions
3. **CIDR Conflicts**: Ensure your chosen CIDR blocks don't conflict with existing networks
4. **EFS Mount Targets**: AWS allows only one EFS mount target per availability zone - this configuration uses two AZs to support both subnets

### Useful Commands

```bash
# Check current state
terraform show

# Import existing resources (if needed)
terraform import aws_vpc.pcluster_vpc vpc-xxxxxxxxx

# Refresh state
terraform refresh
```

## Support

For issues specific to this Terraform configuration, check:
1. Terraform logs and error messages
2. AWS CloudTrail for API call details
3. AWS documentation for service limits and requirements