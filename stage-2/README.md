# ShopSphere: Cloud Architecture Evolution

## Stage 2: EC2 Application Tier + Managed Amazon RDS PostgreSQL

Welcome to **Stage 2** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we transition from the monolithic baseline (Stage 1) to a **decoupled, two-tier cloud architecture** by migrating the database off the EC2 instance onto **Amazon Relational Database Service (Amazon RDS) PostgreSQL** deployed inside isolated private subnets across multiple Availability Zones.

---

## 1. Stage 2 Objective & Evolution Path

```
Stage 1: Single EC2 + Local Database (Baseline Monolith)
   ↓
[ CURRENT ] Stage 2: EC2 + Amazon RDS PostgreSQL (Database Decoupling)
   ↓
Stage 3: ALB + Auto Scaling Group + Multi-EC2 (Horizontal Scaling & High Availability)
   ↓
Stage 4: Amazon ElastiCache / Redis (In-Memory Caching & Session Management)
   ↓
Stage 5: Amazon SQS + AWS Lambda (Asynchronous Order Processing & Decoupled Tasks)
   ↓
Stage 6: Amazon CloudFront + AWS WAF + Multi-AZ Resiliency (Global CDN & Edge Security)
   ↓
Stage 7: Docker Containerization (Standardized Packaging & Microservices)
   ↓
Stage 8: Amazon EKS + Kubernetes (Container Orchestration & Microservice Networking)
   ↓
Stage 9: GitOps + Argo CD + Full Observability (Cloud Native CI/CD & Distributed Tracing)
```

### What Problem Are We Solving from Stage 1?
In Stage 1, hosting PostgreSQL directly on the same EC2 instance introduced major production risks:
- **Resource Contention:** Heavy SQL aggregation or transactional load starved the Node.js event loop and Nginx process of CPU and RAM.
- **Single Point of Failure (SPOF):** If the EC2 instance suffered hardware degradation or an OS crash, both the storefront web server and transactional database were lost simultaneously.
- **Maintenance Downtime:** Upgrading PostgreSQL, OS packages, or resizing EBS volumes required stopping the application.
- **Manual Backups:** Backups required custom cron scripts and snapshots without built-in Point-in-Time Recovery (PITR).

Stage 2 resolves all of these pain points through **Database Decoupling**.

---

## 2. Stage 2 Architecture Diagram

```
+=============================================================================================+
|                                         AWS Cloud                                           |
|                                                                                             |
|  +---------------------------------------------------------------------------------------+  |
|  | Dedicated VPC (10.0.0.0/16)                                                            |  |
|  |                                                                                       |  |
|  |   Internet Gateway (0.0.0.0/0)                                                        |  |
|  |         |                                                                             |  |
|  |         v                                                                             |  |
|  |   +-------------------------------------------------------------------------------+   |  |
|  |   | Public Subnet (10.0.1.0/24) - Availability Zone A                              |   |  |
|  |   |                                                                               |   |  |
|  |   |   +-----------------------------------------------------------------------+   |   |  |
|  |   |   | EC2 Security Group (Port 80/HTTP, 443/HTTPS, 22/SSH)                  |   |  |
|  |   |   |                                                                       |   |  |
|  |   |   |   +---------------------------------------------------------------+   |   |  |
|  |   |   |   | ShopSphere EC2 Application Server (Amazon Linux 2023)         |   |  |
|  |   |   |   | Public IP: Dynamic Public IPv4                                |   |  |
|  |   |   |   | IAM Role: AmazonSSMManagedInstanceCore                        |   |  |
|  |   |   |   |                                                               |   |  |
|  |   |   |   |   [ Port 80 ]                                                 |   |  |
|  |   |   |   |       |                                                       |   |  |
|  |   |   |   |       v                                                       |   |  |
|  |   |   |   |   +---------------------------------------+                   |   |  |
|  |   |   |   |   | Nginx Reverse Proxy                   |                   |   |  |
|  |   |   |   |   +---------------------------------------+                   |   |  |
|  |   |   |   |       | (proxy_pass http://127.0.0.1:8080)                    |   |  |
|  |   |   |   |       v                                                       |   |  |
|  |   |   |   |   +---------------------------------------+                   |   |  |
|  |   |   |   |   | ShopSphere App (Node.js/Express)      |                   |   |  |
|  |   |   |   |   | Listening on :8080 (systemd service)  |                   |   |  |
|  |   |   |   |   +---------------------------------------+                   |   |  |
|  |   |   |   +-------|-------------------------------------------------------+   |   |  |
|  |   |   +-----------|-----------------------------------------------------------+   |   |  |
|  |   +---------------|---------------------------------------------------------------+   |  |
|  |                   |                                                                   |  |
|  |                   | TCP 5432 (Internal Private Traffic Only)                          |  |
|  |                   v                                                                   |  |
|  |   +-------------------------------------------------------------------------------+   |  |
|  |   | Private DB Subnets (Isolated Tier, No Internet Route)                         |   |  |
|  |   |                                                                               |   |  |
|  |   |   Subnet 1: 10.0.10.0/24 (AZ A)      Subnet 2: 10.0.11.0/24 (AZ B)            |   |  |
|  |   |                                                                               |   |  |
|  |   |   +-----------------------------------------------------------------------+   |   |  |
|  |   |   | RDS Security Group (Ingress: TCP 5432 strictly from EC2 SG)          |   |  |
|  |   |   |                                                                       |   |  |
|  |   |   |   +---------------------------------------------------------------+   |   |  |
|  |   |   |   | Amazon RDS PostgreSQL 15 Instance                             |   |  |
|  |   |   |   | Endpoint: shopsphere-stage2-postgres.c...rds.amazonaws.com    |   |  |
|  |   |   |   | Database: shopspheredb | User: shopsphere_user                |   |  |
|  |   |   |   | Storage: 20 GB gp3 (Encrypted, Auto-scaling up to 100 GB)     |   |  |
|  |   |   |   | Automated Backups: 7-day retention + PITR                     |   |  |
|  |   |   |   +---------------------------------------------------------------+   |   |  |
|  |   |   +-----------------------------------------------------------------------+   |   |  |
|  |   +-------------------------------------------------------------------------------+   |  |
|  +---------------------------------------------------------------------------------------+  |
+=============================================================================================+
```

---

## 3. Key Architectural Benefits of Stage 2

1. **Isolation of Concerns & Zero Compute Contention:** The web application and database now have dedicated compute, memory, and IOPS resources. Heavy traffic bursts no longer degrade database query performance.
2. **Enhanced Network Security:** The RDS instance resides in **private subnets** with no public IP address and no route to the Internet Gateway. The database is reachable **only** by instances associated with the EC2 Security Group on port 5432.
3. **Multi-AZ Subnet Group Readiness:** The DB Subnet Group spans across multiple Availability Zones, paving the way for seamless 1-click **Multi-AZ synchronous replication** and automated failover.
4. **Automated Backups & Point-in-Time Recovery (PITR):** AWS RDS automatically takes continuous transaction log backups and daily snapshots, allowing restoration to any second within the retention window.
5. **Storage Auto-Scaling:** Configured with `allocated_storage = 20` and `max_allocated_storage = 100` GB `gp3`, allowing storage to grow dynamically as order volumes expand without manual intervention.

---

## 4. AWS Resources Provisioned

| Resource | Terraform Type | Purpose |
| :--- | :--- | :--- |
| **VPC** | `aws_vpc` | Isolated virtual network (`10.0.0.0/16`) |
| **Internet Gateway** | `aws_internet_gateway` | Ingress and egress connectivity for the public compute subnet |
| **Public Subnet** | `aws_subnet` | Subnet in AZ 1 (`10.0.1.0/24`) with auto-assigned public IPs |
| **Private DB Subnets** | `aws_subnet` (x2) | Dedicated private subnets (`10.0.10.0/24`, `10.0.11.0/24`) across 2 AZs |
| **Route Tables** | `aws_route_table` (x2) | Public RT for IGW; Private RT for complete internet isolation |
| **EC2 Security Group** | `aws_security_group` | Ingress: 80 (HTTP), 443 (HTTPS), 22 (Admin SSH) |
| **RDS Security Group** | `aws_security_group` | Ingress: 5432 (PostgreSQL) strictly from `ec2_security_group` |
| **DB Subnet Group** | `aws_db_subnet_group` | Multi-AZ subnet group for Amazon RDS |
| **DB Parameter Group** | `aws_db_parameter_group` | Custom PostgreSQL 15 parameters with connection logging |
| **Amazon RDS Instance** | `aws_db_instance` | Managed PostgreSQL 15 engine, encrypted `gp3` storage |
| **IAM Role & Profile** | `aws_iam_role`, `aws_iam_instance_profile` | Attaches `AmazonSSMManagedInstanceCore` for secure SSM terminal access |
| **EC2 Instance** | `aws_instance` | Node.js 20 LTS runtime, Nginx reverse proxy |

---

## 5. Directory Structure

```
stage-2/
├── app/                                    # ShopSphere Application Source
│   ├── package.json                        # Node.js dependencies & scripts
│   ├── server.js                           # Express application configured for Amazon RDS
│   ├── .env.example                        # Example environment template
│   ├── db/
│   │   └── schema.sql                      # PostgreSQL schema DDL and initial catalog seeds
│   └── public/
│       ├── index.html                      # Modern storefront UI (Stage 2 metrics & status)
│       └── styles.css                      # Modern dark-mode styling
├── terraform/                              # Stage 2 Modular Terraform Code
│   ├── main.tf                             # Root orchestration & module declarations
│   ├── provider.tf                         # AWS provider definition
│   ├── variables.tf                        # Root variable definitions
│   ├── outputs.tf                          # Root output declarations (IPs, RDS endpoints, URLs)
│   ├── versions.tf                         # Terraform & AWS provider version constraints
│   ├── data.tf                             # Dynamic AMI and Availability Zone discovery
│   ├── terraform.tfvars.example            # Sample configuration values
│   ├── scripts/
│   │   └── user_data.sh.tpl                # Cloud-init bootstrap script (RDS waiting & setup)
│   └── modules/
│       ├── vpc/                            # Multi-tier VPC (Public + Private subnets across AZs)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security-group/                 # EC2 and RDS Security Groups
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── rds/                            # Amazon RDS PostgreSQL 15 Module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── ec2/                            # EC2 Compute Server Module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── README.md                               # Stage 2 Documentation
```

---

## 6. Prerequisites

Before deploying Stage 2, ensure you have:
1. **AWS Account** with permissions for VPC, EC2, RDS, and IAM.
2. **AWS CLI** installed and configured (`aws configure` with valid credentials).
3. **Terraform CLI** (v1.5.0 or newer) installed.

---

## 7. Deployment Guide

### Step 1: Navigate to the Terraform Directory
```bash
cd /vagrant_data/AI/stage-2/terraform
```

### Step 2: Configure Input Variables
Create `terraform.tfvars` from the example template:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize settings:
```hcl
aws_region   = "us-east-1"
project_name = "shopsphere"
environment  = "stage2"

# Restrict SSH access to your public IP
admin_cidr   = ["YOUR_PUBLIC_IP/32"]

# RDS database settings
db_name      = "shopspheredb"
db_user      = "shopsphere_user"
db_password  = "YourSuperSecretStrongPassword123!"
```

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Validate Configuration
```bash
terraform validate
```

### Step 5: Plan Infrastructure
```bash
terraform plan
```

### Step 6: Apply & Deploy
```bash
terraform apply
```
Type `yes` when prompted. Terraform will provision the VPC, subnets, route tables, security groups, RDS PostgreSQL database, and EC2 instance.

> [!NOTE]
> RDS database provisioning usually takes between 3 to 6 minutes. The EC2 instance user-data will automatically wait for the RDS endpoint to become reachable before starting the Node.js application.

---

## 8. Verifying the Deployment

Once `terraform apply` finishes, access the outputs:

- **Storefront Web UI:**
  ```
  http://<EC2_PUBLIC_IP>/
  ```
- **Health Check Endpoint:**
  ```
  http://<EC2_PUBLIC_IP>/health
  ```
  *Example Response:*
  ```json
  {
    "status": "UP",
    "stage": "Stage 2: EC2 + Amazon RDS PostgreSQL (Decoupled Database)",
    "application": "ShopSphere Application Server",
    "version": "2.0.0",
    "database": {
      "engine": "Amazon RDS PostgreSQL",
      "version": "15.7",
      "status": "connected",
      "host": "shopsphere-stage2-postgres.c...rds.amazonaws.com",
      "port": 5432,
      "name": "shopspheredb",
      "latencyMs": 3
    }
  }
  ```
- **System Info Endpoint:**
  ```
  http://<EC2_PUBLIC_IP>/api/system/info
  ```
- **Product Catalog API:**
  ```
  http://<EC2_PUBLIC_IP>/api/products
  ```

---

## 9. Connecting to EC2 & Validating RDS

### Connect via AWS Systems Manager Session Manager (Recommended)
```bash
aws ssm start-session --target <EC2_INSTANCE_ID>
```

### Verify Application & PostgreSQL Client Connectivity from EC2
Inside the EC2 instance terminal:
```bash
# 1. Check application service status
sudo systemctl status shopsphere.service

# 2. View real-time application logs
sudo journalctl -u shopsphere.service -n 50 -f

# 3. Test direct psql connection to Amazon RDS
psql -h <RDS_ENDPOINT_ADDRESS> -U shopsphere_user -d shopspheredb -c "\dt"

# 4. View bootstrap log
sudo cat /var/log/user-data.log
```

---

## 10. Clean Up & Infrastructure Teardown

When you are done testing Stage 2, delete all provisioned AWS cloud resources to avoid ongoing charges:

```bash
cd /vagrant_data/AI/stage-2/terraform
terraform destroy
```

Type `yes` when prompted. Terraform will terminate the EC2 instance, delete the Amazon RDS instance (with `skip_final_snapshot = true`), security groups, subnets, route tables, internet gateway, and VPC.
