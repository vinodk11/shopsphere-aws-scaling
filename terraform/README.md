# ShopSphere Stage 1: Single EC2 + Database

## Project Objective

The ShopSphere project demonstrates the evolution of an e-commerce application from a single-server architecture to a highly scalable AWS architecture and eventually to Amazon EKS/Kubernetes. Stage 1 establishes the baseline by provisioning a single EC2 instance running the ShopSphere monolithic application with a local MongoDB database.

This stage is intentionally simple and serves as the foundation for subsequent stages that will add RDS, ALB, auto scaling, caching, and Kubernetes deployment.

## Stage 1 Architecture

```
Internet
  |
  v
+----------------------+
|   Internet Gateway   |
+----------+-----------+
           |
           v
+----------------------+
|      VPC (10.0.0.0/16) |
+----------+-----------+
           |
           v
+----------------------+
| Public Subnet (10.0.1.0/24) |
+----------+-----------+
           |
           v
+----------------------+
|   EC2 Instance       |
|  t3.small + Amazon Linux 2023  |
|  +-- ShopSphere App  |   (Java Spring Boot, port 8080)
|  +-- MongoDB 7.0     |   (local, port 27017)
|  +-- Redis           |   (local, port 6379)
|  +-- Nginx           |   (reverse proxy, port 80)
+----------+-----------+
           |
           v
+----------------------+
|  Application URL:    |
|  http://<public-ip>  |
+----------------------+
```

## AWS Resources Created

1. **VPC** - Isolated network with CIDR 10.0.0.0/16
2. **Internet Gateway** - Enables internet connectivity for the public subnet
3. **Public Subnet** - 10.0.1.0/24 in us-east-1a with auto-assign public IP enabled
4. **Route Table** - Directs 0.0.0.0/0 traffic through the Internet Gateway
5. **Route Table Association** - Associates the public subnet with the public route table
6. **Security Group** - Restricted access:
   - HTTP (80) from 0.0.0.0/0
   - HTTPS (443) from 0.0.0.0/0
   - SSH (22) from admin_cidr only (default: empty, restrict further)
   - All outbound traffic allowed
7. **EC2 Instance** - t3.small running Amazon Linux 2023
8. **IAM Role/Profile** - AmazonSSMManagedInstanceCore for SSM Session Manager access
9. **MongoDB 7.0** - Installed and configured locally on EC2 with authentication
10. **Redis** - Installed locally on EC2
11. **ShopSphere Application** - Java Spring Boot microservices (api-gateway on port 8080)
12. **Nginx** - Reverse proxy listening on port 80, forwarding to application on port 8080

## Network Architecture

- **VPC**: Single VPC in one Availability Zone (us-east-1a)
- **Subnet**: Public subnet with `map_public_ip_on_launch = true`
- **Internet Gateway**: Attached to VPC, enables outbound internet and inbound HTTP/HTTPS
- **Route Table**: Default route `0.0.0.0/0 -> Internet Gateway`
- **Security Group**: Restricted inbound rules; SSH limited to admin_cidR, HTTP/HTTPS open for application access

## Application Architecture

- **Language/Framework**: Java 17, Spring Boot 3.2.3
- **Build System**: Maven
- **Architecture**: Microservices with API Gateway
- **Application Port**: 8080 (api-gateway)
- **Reverse Proxy**: Nginx on port 80, forwarding to backend services
- **Services and Ports**:
  - api-gateway: 8080 (entry point)
  - product-service: 8081
  - order-service: 8082
  - user-service: 8083
  - cart-service: 8084
  - payment-service: 8085
  - shipping-service: 8086
  - review-service: 8087
  - notification-service: 8088

- **Database**: MongoDB 7.0 (local, port 27017)
- **Cache**: Redis (local, port 6379)
- **Configuration**: All services connect to `localhost` for MongoDB and Redis since they run on the same EC2 instance
- **Environment Variables**: MongoDB URI, JWT secret, Redis host configured via /opt/shopsphere/app.env

## Database Architecture

- **Database Type**: MongoDB 7.0
- **Location**: Local on the same EC2 instance (/data directory)
- **Data Directory**: /var/lib/mongo
- **Authentication**: Enabled with admin user
- **Admin User**: `shopsphere_admin` (configured via db_username variable)
- **Database Names per Service**:
  - shopsphere_users (user-service)
  - shopsphere_products (product-service)
  - shopsphere_orders (order-service)
  - shop
  (and similarly for cart, payment, shipping, review, notification services)

- **Important**: Do not store production passwords in Terraform. Use `db_username` and `db_password` variables, but eventually move these to AWS Secrets Manager or HashiCorp Vault.

## Terraform Directory Structure

```
shopsphere/
└── terraform/
    ├── main.tf          # Module orchestration (calls vpc, security-group, ec2 modules)
    ├── provider.tf      # AWS provider configuration
    ├── versions.tf      # Terraform and provider version pinning
    ├── variables.tf     # Input variables
    ├── data.tf          # Data sources (AMI lookup)
    ├── outputs.tf       # Output values
    ├── terraform.tfvars.example  # Example variables file
    └── modules/
        ├── vpc/
        │   ├── main.tf      # VPC, IGW, subnet, route table
        │   ├── variables.tf # VPC networking variables
        │   └── outputs.tf   # VPC output values
        ├── security-group/
        │   ├── main.tf      # Security group with HTTP/HTTPS/SSH rules
        │   ├── variables.tf # SG variables (project, env, vpc_id, admin_cidr)
        │   └── outputs.tf   # SG output values
        └── ec2/
            ├── main.tf      # EC2 instance with user_data bootstrap
            ├── variables.tf # EC2 variables (instance type, volumes, app config)
            ├── outputs.tf   # EC2 output values
            └── bootstrap.sh.tftpl  # EC2 user_data bootstrap script
```

## Prerequisites

### AWS Account

- Active AWS account with appropriate IAM permissions
- Administrator access or equivalent for creating VPC, EC2, IAM resources

### Local Tools

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/user/getting-started/install.html) (optional, for validation)
- SSH key pair (optional, for direct EC2 SSH; SSM Session Manager can be used as alternative)

### SSH Key Pair (Optional)

- Create an SSH key pair in your AWS account for direct EC2 instance access
- Or rely on AWS SSM Session Manager for browser-based SSH access
- If using an SSH key, set `key_name` variable to the key pair name

## Configuration

### 1. Copy the example terraform variables

```bash
cd shopsphere/terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

Fill in the required values:

```hcl
# Required: Your public IP for SSH access
admin_cidr = ["203.0.113.42/32"]  # Replace with your actual public IP

# Optional: Custom key pair name
# key_name = "my-shopsphere-key"

# Optional: Override defaults if needed
# aws_region       = "us-west-2"
# availability_zone = "us-west-2a"
# instance_type     = "t3.medium"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the planned changes

```bash
terraform plan
```

### 5. Apply the infrastructure

```bash
terraform apply
```

## Terraform Deployment Commands

```bash
# 1. Initialize the working directory
terraform init

# 2. Review the execution plan
terraform plan

# 3. Apply the infrastructure
terraform apply

# 4. Destroy the infrastructure when finished
terraform destroy
```

## How to Access ShopSphere

### Application URL

After `terraform apply` completes, the application will be accessible at:

```
http://<ec2-public-ip>
```

Nginx is configured as a reverse proxy on port 80, forwarding requests to the ShopSphere API Gateway running on port 8080.

### Using AWS SSM Session Manager (Recommended)

Instead of SSH keys, you can use AWS Systems Manager Session Manager to access the instance:

```bash
# From AWS CLI
aws ssm start-session --target <ec2-instance-id>

# Or from AWS Console: Connect to the instance using Session Manager
```

### Using SSH (if key pair is configured)

```bash
ssh -i /path/to/your/key.pem ec2-user@<ec2-public-dns-or-ip>
```

## How to SSH into the Instance

### Using Session Manager (No key required)

1. After `terraform apply`, note the `ec2_instance_id` output
2. Use AWS Console or CLI:
   ```bash
   aws ssm start-session --target <instance-id>
   ```

### Using SSH Key Pair

1. If `key_name` is set in variables, the key is automatically associated with the instance
2. Find the instance public DNS or IP from Terraform outputs
3. SSH using the ec2-user account:
   ```bash
   ssh -i /path/to/key.pem ec2-user@<public-dns>
   ```

### If no key pair is set

The instance relies on SSM Session Manager. Use the AWS Console or CLI to connect via Session Manager.

## How to Troubleshoot Application Startup

### Check Bootstrap Logs

```bash
# View user data execution log
cat /var/log/user-data.log

# Check if MongoDB is running
systemctl status mongod

# Check if Redis is running
systemctl status redis

# Check if Nginx is running
systemctl status nginx

# Check if ShopSphere service is running
systemctl status shopsphere
```

### Common Issues

1. **Application won't start**:
   - Check `/opt/shopsphere/app.log` or journalctl: `journalctl -u shopsphere -f`
   - Verify MongoDB is running and accessible
   - Check that the JAR file exists at `/opt/shopsphere/app/api-gateway/target/shopsphere.jar`

2. **MongoDB connection failures**:
   - Verify MongoDB authentication is working
   - Check `/etc/mongod.conf` for correct configuration
   - Ensure the MongoDB URI in `/opt/shopsphere/app.env` matches the deployed configuration

3. **Nginx reverse proxy issues**:
   - Check Nginx config: `cat /etc/nginx/conf.d/shopsphere.conf`
   - Test upstream: `curl -s http://localhost:8080/actuator/health`
   - Verify Nginx is running and the configuration is valid: `nginx -t`

4. **SSH connection issues**:
   - If using Session Manager: Ensure AWS SSM agent is running
   - If using SSH keys: Verify the key matches the key pair in AWS
   - Check instance status in the AWS Console

## How to Destroy the Infrastructure

When you're finished evaluating ShopSphere Stage 1, destroy all created resources:

```bash
cd shopsphere/terraform
terraform destroy
```

**Warning**: This will terminate the EC2 instance, delete the VPC, and remove all associated resources. Any data stored locally on the instance (including MongoDB data) will be lost.

## Architecture Evolution Path

Stage 1 → Stage 2: Add Amazon RDS → Stage 3: ALB + Auto Scaling → Stage 4: ElastiCache/Redis → Stage 5: SQS + Lambda → Stage 6: CloudFront + WAF → Stage 7: Docker + Containerization → Stage 8: Amazon EKS + Kubernetes → Stage 9: GitOps + Argo CD + Observability

## Assumptions

- The ShopSphere application is a Java Spring Boot microservices architecture
- MongoDB is the primary database (all services use `data.mongodb` configuration)
- Redis is used as a cache (all services use `data.redis` configuration)
- The API Gateway serves as the entry point on port 8080
- Nginx is used as a reverse proxy on port 80
- One Availability Zone is used for Stage 1 (multi-AZ will be added in later stages)