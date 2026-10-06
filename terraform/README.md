# HeatmapJapan Terraform Infrastructure

Terraform infrastructure for HeatmapJapan project with dev and prod environments.

## Directory Structure

```
terraform/
├── modules/
│   └── valkey/             # Valkey (Redis) module
├── environments/           # Environment configurations
│   ├── dev/               # Development environment
│   └── prod/             # Production environment
├── main.tf              # Main Terraform file
├── variables.tf        # Variable definitions
└── outputs.tf         # Output values
```

## Prerequisites

- **Terraform** >= 1.5
- **AWS CLI** configured
- **AWS permissions** for EC2, VPC, ElastiCache

## Quick Setup

### 1. Create Backend Resources (One-time setup)

Create S3 buckets for state storage:

```bash
# Dev environment
aws s3 mb s3://faber-terraform-state-develop --region ap-northeast-1
aws s3api put-bucket-versioning --bucket faber-terraform-state-develop --versioning-configuration Status=Enabled

# Prod environment  
aws s3 mb s3://faber-terraform-state-production --region ap-northeast-1
aws s3api put-bucket-versioning --bucket faber-terraform-state-production --versioning-configuration Status=Enabled
```

Create DynamoDB table for state locking (shared):

```bash
# Shared state locking table for all environments
aws dynamodb create-table \
  --table-name faber-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region ap-northeast-1
```

### 2. Deploy Dev Environment

```bash
cd environments/dev
terraform init
terraform plan -out="terraform.dev.plan"
terraform apply "terraform.dev.plan"
```

### 3. Deploy Prod Environment

```bash
cd environments/prod
terraform init
terraform plan -out="terraform.prod.plan"
terraform apply "terraform.prod.plan"
```

## Valkey Configuration

### Dev Environment
- **Instance**: cache.t4g.micro (smallest ARM-based)
- **Memory**: 0.555GB RAM
- **Nodes**: 1 (single node for cost savings)
- **Multi-AZ**: Disabled
- **Encryption**: Disabled (for simplicity)
- **Backup**: 1-day retention

### Prod Environment  
- **Instance**: cache.t4g.small (cost-effective for 1GB data)
- **Memory**: 1.37GB RAM per node
- **Nodes**: 2 (primary + replica for HA)
- **Multi-AZ**: Enabled
- **Encryption**: Disabled (for simplicity)
- **Backup**: 7-day retention

## Get Connection Info

After deployment:

```bash
terraform output valkey_endpoint
terraform output valkey_port
```

## Estimated Costs (Monthly)

- **Dev**: ~$12/month (cache.t4g.micro single node)
- **Prod**: ~$24/month (cache.t4g.small 2 nodes)
- **Total**: ~$36/month for both environments

**Note**: Uses existing VPC infrastructure, no additional NAT Gateway costs.

## Accessing Valkey/Redis

### From EC2 Instance (Both Environments)
```bash
# SSH to EC2 instance in same VPC
ssh ec2-user@your-ec2-instance

# Install redis-cli if not available
sudo yum install redis -y
# or for Ubuntu
sudo apt-get install redis-tools -y

# Connect to Valkey (simple connection for both dev and prod)
redis-cli -h <valkey_endpoint> -p 6379

# Test connection
> ping
PONG
```

## Security

- State files stored in encrypted S3 buckets with versioning
- DynamoDB state locking enabled
- Valkey encryption disabled (both environments for simplicity)
- Security groups restrict access to EC2 instances only
- Default tags applied automatically via provider configuration
- **Network isolation**: Both environments protected by VPC security groups
- **Access control**: Only authorized EC2 instances can connect

## Support

For infrastructure issues, contact the DevOps team.