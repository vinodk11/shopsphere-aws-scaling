# ShopSphere: Cloud Architecture Evolution

## Stage 3: ALB + Auto Scaling Group + Multi-EC2 + Amazon RDS

Welcome to **Stage 3** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we transition from a single compute server (Stage 2) to a **highly available, horizontally scalable, multi-AZ compute tier** using an **AWS Application Load Balancer (ALB)** and an **EC2 Auto Scaling Group (ASG)** backed by our decoupled **Amazon Relational Database Service (Amazon RDS) PostgreSQL** database.

---

## 1. Stage 3 Objective & Evolution Path

```
Stage 1: Single EC2 + Local Database (Baseline Monolith)
   ↓
Stage 2: EC2 + Amazon RDS PostgreSQL (Database Decoupling)
   ↓
[ CURRENT ] Stage 3: ALB + Auto Scaling Group + Multi-EC2 (Horizontal Scaling & High Availability)
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

### What Problem Are We Solving from Stage 2?
While Stage 2 eliminated database resource contention by migrating PostgreSQL to managed Amazon RDS, it left the application tier vulnerable to critical production limitations:
- **Compute Single Point of Failure (SPOF):** If the single EC2 application instance suffered an OS kernel panic, hardware degradation, or rebooted during patching, the entire ShopSphere storefront went offline.
- **Inability to Scale Horizontally:** Vertical scaling (upgrading instance size) requires scheduled downtime and encounters strict physical compute ceilings. Under sudden traffic surges (e.g. Flash Sales), a single instance exhausts its CPU and memory.
- **Single Availability Zone Risk:** The compute layer was pinned to a single AWS Availability Zone (`us-east-1a`). An AZ-wide power or networking incident would take down the application.
- **Direct Internet Exposure of Compute:** In Stage 2, the EC2 instance was directly exposed to incoming internet traffic on port 80.

**Stage 3 resolves all of these risks** by introducing an intelligent traffic distribution tier (ALB) and an elastic self-healing fleet of EC2 instances spanning multiple Availability Zones.

---

## 2. Stage 3 Architecture Diagram

```
+===================================================================================================================+
|                                                    AWS Cloud                                                      |
|                                                                                                                   |
|  +-------------------------------------------------------------------------------------------------------------+  |
|  | Dedicated VPC (10.0.0.0/16)                                                                                  |  |
|  |                                                                                                             |  |
|  |   Internet Gateway (0.0.0.0/0)                                                                              |  |
|  |         |                                                                                                   |  |
|  |         v                                                                                                   |  |
|  |   +-----------------------------------------------------------------------------------------------------+   |  |
|  |   | Application Load Balancer (ALB) Tier (Public Subnets across AZ-A & AZ-B)                            |   |  |
|  |   | ALB Security Group: Ingress 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0                                   |   |  |
|  |   | DNS: shopsphere-stage3-alb-XXXXXXXX.us-east-1.elb.amazonaws.com                                      |   |  |
|  |   +-----------------------------------------------------------------------------------------------------+   |  |
|  |         |                                                           |                                       |  |
|  |         | HTTP (Round-Robin)                                        | HTTP (Round-Robin)                    |  |
|  |         v                                                           v                                       |  |
|  |   +-----------------------------------------+   +-----------------------------------------+                 |  |
|  |   | Public Subnet 1: 10.0.1.0/24 (AZ-A)     |   | Public Subnet 2: 10.0.2.0/24 (AZ-B)     |                 |  |
|  |   |                                         |   |                                         |                 |  |
|  |   |  +-----------------------------------+  |   |  +-----------------------------------+  |                 |  |
|  |   |  | EC2 Instance 1 (Auto Scaling Group)|  |   |  | EC2 Instance 2 (Auto Scaling Group)|  |                 |  |
|  |   |  | EC2 SG: Port 80 from ALB SG ONLY   |  |   |  | EC2 SG: Port 80 from ALB SG ONLY   |  |                 |  |
|  |   |  | Node.js 20 App + Nginx Reverse     |  |   |  | Node.js 20 App + Nginx Reverse     |  |                 |  |
|  |   |  +-----------------------------------+  |   |  +-----------------------------------+  |                 |  |
|  |   +-----------------------------------------+   +-----------------------------------------+                 |  |
|  |         \                                                           /                                       |  |
|  |          \                                                         /                                        |  |
|  |           \---- TCP 5432 (Internal Private Traffic Only) ---------/                                         |  |
|  |                                       |                                                                     |  |
|  |                                       v                                                                     |  |
|  |   +-----------------------------------------------------------------------------------------------------+   |  |
|  |   | Private DB Subnets (Isolated Tier, No Internet Route)                                               |   |  |
|  |   |   Subnet 1: 10.0.10.0/24 (AZ-A)               Subnet 2: 10.0.11.0/24 (AZ-B)                         |   |  |
|  |   |                                                                                                     |   |  |
|  |   |   +---------------------------------------------------------------------------------------------+   |   |  |
|  |   |   | RDS Security Group (Ingress: TCP 5432 strictly from EC2 ASG SG)                            |   |  |
|  |   |   |                                                                                             |   |  |
|  |   |   |   +-------------------------------------------------------------------------------------+   |   |  |
|  |   |   |   | Amazon RDS PostgreSQL 15 Instance                                                   |   |   |  |
|  |   |   |   | Endpoint: shopsphere-stage3-postgres.c...rds.amazonaws.com                          |   |   |  |
|  |   |   |   | Storage: 20 GB gp3 (Encrypted, Auto-scaling up to 100 GB)                           |   |   |  |
|  |   |   |   | Backups: 7-day retention + Automated PITR                                           |   |   |  |
|  |   |   |   +-------------------------------------------------------------------------------------+   |   |  |
|  |   |   +---------------------------------------------------------------------------------------------+   |   |  |
|  |   +-----------------------------------------------------------------------------------------------------+   |  |
|  +-------------------------------------------------------------------------------------------------------------+  |
+===================================================================================================================+
```

---

## 3. Key Architectural Benefits of Stage 3

1. **High Availability & Zero Single Point of Failure:** By distributing application instances across multiple Availability Zones, the loss of an entire AZ does not take down ShopSphere. The ALB seamlessly routes all traffic to healthy instances in the surviving zone.
2. **Horizontal Elastic Scaling:** The Auto Scaling Group dynamically grows from 2 instances up to 4 instances automatically based on real-time CPU utilization targets (`ASGAverageCPUUtilization >= 70%`). When traffic subsides, it automatically scales back down to reduce infrastructure costs.
3. **Automated Fleet Self-Healing:** The ALB continuously monitors backend instances via `/health`. If an instance crashes, stops responding, or loses database connectivity, the ALB marks it unhealthy, stops routing user requests to it, and the Auto Scaling Group terminates and replaces it automatically.
4. **Enhanced Layered Security:** The EC2 application instances no longer accept direct public web traffic. Their security group accepts HTTP traffic on port 80 **strictly from the Application Load Balancer Security Group**. Direct internet bypass is blocked at the network packet level.
5. **Zero-Downtime Rolling Upgrades:** The ASG is configured with `instance_refresh` using a `Rolling` strategy. When application updates or AMI patches are introduced, instances are replaced incrementally with health-check verification before old instances are decommissioned.

---

## 4. AWS Resources Provisioned

| Resource | Terraform Type | Purpose |
| :--- | :--- | :--- |
| **VPC** | `aws_vpc` | Dedicated virtual cloud network (`10.0.0.0/16`) |
| **Internet Gateway** | `aws_internet_gateway` | Gateway providing internet connectivity for the public tier |
| **Public Subnets** (x2) | `aws_subnet` | Subnets spanning AZ-A (`10.0.1.0/24`) and AZ-B (`10.0.2.0/24`) |
| **Private DB Subnets** (x2) | `aws_subnet` | Isolated subnets spanning AZ-A (`10.0.10.0/24`) and AZ-B (`10.0.11.0/24`) |
| **Route Tables** | `aws_route_table` (x2) | Public RT (routes to IGW); Private RT (isolated database) |
| **ALB Security Group** | `aws_security_group` | Public ingress: Port 80 (HTTP), Port 443 (HTTPS) |
| **EC2 Security Group** | `aws_security_group` | Ingress: Port 80 strictly from `alb_security_group`; SSH from `admin_cidr` |
| **RDS Security Group** | `aws_security_group` | Ingress: Port 5432 strictly from `ec2_security_group` |
| **Application Load Balancer** | `aws_lb` | Internet-facing layer-7 load balancer spanning multi-AZ public subnets |
| **Target Group** | `aws_lb_target_group` | Groups EC2 instances with HTTP `/health` check probing every 15 seconds |
| **ALB Listener** | `aws_lb_listener` | Listens on port 80 and forwards requests to target group |
| **Launch Template** | `aws_launch_template` | EC2 configuration template (AMI, t3.micro, IAM profile, user-data bootstrap) |
| **Auto Scaling Group** | `aws_autoscaling_group` | Fleet manager: Min 2, Desired 2, Max 4 across multi-AZ |
| **Scaling Policy** | `aws_autoscaling_policy` | Target tracking scaling policy on average CPU utilization (70%) |
| **IAM Role & Profile** | `aws_iam_role`, `aws_iam_instance_profile` | Attaches `AmazonSSMManagedInstanceCore` for AWS Systems Manager |
| **DB Subnet Group** | `aws_db_subnet_group` | Multi-AZ subnet group for Amazon RDS |
| **DB Parameter Group** | `aws_db_parameter_group` | Custom PostgreSQL 15 configuration with connection auditing |
| **Amazon RDS Instance** | `aws_db_instance` | Managed PostgreSQL 15 engine, encrypted `gp3` storage, auto-scaling up to 100 GB |

---

## 5. Directory Structure

```
stage-3/
├── app/                                    # ShopSphere Stage 3 Application Source
│   ├── package.json                        # Node.js dependencies & scripts (v3.0.0)
│   ├── server.js                           # Express application with multi-instance awareness
│   ├── .env.example                        # Example environment template
│   ├── db/
│   │   └── schema.sql                      # Idempotent PostgreSQL schema and catalog seed data
│   └── public/
│       ├── index.html                      # Modern storefront UI with ALB round-robin tester
│       └── styles.css                      # Modern dark styling & load-balancer visualizer
├── terraform/                              # Stage 3 Modular Terraform Code
│   ├── main.tf                             # Root orchestration connecting modules
│   ├── provider.tf                         # AWS provider definition
│   ├── variables.tf                        # Root input variable definitions
│   ├── outputs.tf                          # Root outputs (ALB DNS, Target Group, ASG, RDS)
│   ├── versions.tf                         # Terraform & AWS provider constraints
│   ├── data.tf                             # Dynamic AMI and Availability Zone discovery
│   ├── terraform.tfvars.example            # Sample configuration values
│   ├── scripts/
│   │   └── user_data.sh.tpl                # Cloud-init bootstrap script for ASG instances
│   └── modules/
│       ├── vpc/                            # Multi-AZ VPC (Public + Private subnets)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security-group/                 # Tiered Security Groups (ALB, EC2 ASG, RDS)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── alb/                            # Application Load Balancer & Target Group Module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── asg/                            # Auto Scaling Group & Launch Template Module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── rds/                            # Amazon RDS PostgreSQL 15 Module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── Jenkinsfile                             # Dedicated Jenkins pipeline for Stage 3
└── README.md                               # Stage 3 Documentation
```

---

## 6. Deployment Guide

### Option A: Deploy via Terraform CLI

#### Step 1: Navigate to the Stage 3 Terraform Directory
```bash
cd /vagrant/dev_projects/shopsphere-aws-scaling/stage-3/terraform
```

#### Step 2: Configure Input Variables
Create `terraform.tfvars` from the example template:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Customize settings in `terraform.tfvars` as needed:
```hcl
aws_region   = "us-east-1"
project_name = "shopsphere"
environment  = "stage3"

# Restrict SSH access to your public IP
admin_cidr   = ["YOUR_PUBLIC_IP/32"]

# Auto Scaling Group Fleet Sizing
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4

# RDS database settings
db_name      = "shopspheredb"
db_user      = "shopsphere_user"
db_password  = "YourSuperSecretStrongPassword123!"
```

#### Step 3: Initialize Terraform
```bash
terraform init
```

#### Step 4: Validate Configuration
```bash
terraform validate
```

#### Step 5: Plan Infrastructure
```bash
terraform plan
```

#### Step 6: Apply & Provision
```bash
terraform apply
```
Type `yes` when prompted. Terraform will provision the multi-AZ VPC, security groups, ALB, Target Group, RDS database, Launch Template, and Auto Scaling Group.

---

### Option B: Deploy via Jenkins Pipeline

You can deploy Stage 3 automatically using either:
1. **Dedicated Pipeline:** Point a Jenkins pipeline job to `stage-3/Jenkinsfile`.
2. **Root Multi-Stage Pipeline:** Run the root `Jenkinsfile`, select `STAGE = stage-3`, choose `ACTION = apply`, and trigger the build.

#### Required Jenkins Plugins

To ensure the declarative pipeline executes without syntax errors, the following plugins must be installed in Jenkins (**Manage Jenkins** &rarr; **Plugins** &rarr; **Available plugins**):

| Plugin Name | Plugin ID / Short Name | Purpose & Requirement |
| :--- | :--- | :--- |
| **Pipeline** | `workflow-aggregator` | Core Declarative Pipeline engine (`pipeline { ... }`, `stages`, `script`, `parameters`) |
| **Git plugin** | `git` | SCM repository cloning (`git branch: 'main', url: '...'`) |
| **AnsiColor** | `ansicolor` | **Critical!** Enables terminal ANSI color parsing (`ansiColor('xterm')`). Without this plugin, the pipeline immediately crashes with `NoSuchMethodError: No such DSL method 'ansiColor'`. |
| **Pipeline: Input Step** | `pipeline-input-step` | Powers the manual `Approval Gate` before Terraform apply/destroy |
| **Docker Pipeline** *(Optional)* | `docker-workflow` | Docker integration and container lifecycle management |
| **Credentials Binding** *(Optional)* | `credentials-binding` | Secure binding of AWS credentials or API tokens |

#### Jenkins Server Host Prerequisites

The pipeline executes Terraform inside a `hashicorp/terraform:latest` container using the host's Docker socket:

1. **Docker Service Running:**
   ```bash
   sudo systemctl enable --now docker
   ```

2. **Grant Docker Permissions to Jenkins User:**
   ```bash
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```
   > [!IMPORTANT]
   > After adding `jenkins` to the `docker` group, restart the Jenkins daemon so that permissions take effect.

3. **AWS Authentication:**
   The container automatically inherits AWS credentials from either:
   - The Jenkins EC2 server's **IAM Instance Profile** (`AmazonEC2FullAccess`, `AmazonVPCFullAccess`, `AmazonRDSFullAccess`), or
   - `~/.aws/credentials` configured on the Jenkins host.

---

## 7. Verifying the Deployment & Testing

Once `terraform apply` finishes, review the outputs:

### 1. Access the Storefront via ALB
Open the Application Load Balancer DNS name in your browser:
```
http://<alb_dns_name>
```
You will see the **ShopSphere Stage 3 Storefront**. Notice:
- The **Active Serving Hostname** badge at the top shows which ASG EC2 instance served the web page.
- The **Amazon RDS Connected** pulse badge indicates sub-10ms transactional database latency.

### 2. Test ALB Round-Robin Load Balancing
In the storefront UI, click the **"Test ALB Round-Robin (10 Requests)"** button, or run the following command from your terminal:
```bash
for i in {1..10}; do
  curl -s "http://<alb_dns_name>/api/instance-info" | grep -o '"hostname":"[^"]*"'
  sleep 0.3
done
```
**Expected Output:** You will see alternating hostnames (e.g. `ip-10-0-1-45` and `ip-10-0-2-89`), confirming that the Application Load Balancer is actively distributing requests across the multi-AZ instance fleet!

### 3. Place an ACID Order
Add an item to your cart and place an order.
- The order is processed with ACID transaction consistency in Amazon RDS.
- The order record logs the exact EC2 host (`served_by_host`) that executed the transaction.
- Open **Architecture Info** to view recent orders and see the instances that handled them.

### 4. Verify AWS Target Group Health via AWS CLI
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```
All registered ASG targets will report:
```json
"TargetHealth": {
    "State": "healthy"
}
```

### 5. Chaos Testing: Self-Healing & Automatic Replacement
To verify the high availability and self-healing capability of the Auto Scaling Group:
1. Identify one of the running EC2 instances in your AWS console or via CLI:
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-name $(terraform output -raw asg_name) \
     --query 'AutoScalingGroups[0].Instances[*].InstanceId'
   ```
2. Manually terminate one instance:
   ```bash
   aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
   ```
3. Observe that:
   - The storefront web application experiences **zero downtime** because the ALB immediately routes 100% of traffic to the remaining healthy instance.
   - Within 1 to 2 minutes, the Auto Scaling Group detects that the fleet size dropped below the desired capacity (`2`) and automatically launches a replacement EC2 instance in the appropriate AZ.
   - Once the new instance passes its `/health` check, it automatically joins the target group and begins receiving traffic.

---

## 8. Teardown Instructions

To destroy all AWS infrastructure provisioned in Stage 3:

```bash
cd /vagrant/dev_projects/shopsphere-aws-scaling/stage-3/terraform
terraform destroy
```
Type `yes` when prompted. All resources (ALB, ASG, Launch Template, Target Group, RDS, Security Groups, Subnets, VPC) will be cleanly removed.
