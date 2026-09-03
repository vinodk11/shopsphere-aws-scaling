# ShopSphere: Cloud Architecture Evolution

## Stage 1: Single EC2 Instance + Colocated Database

Welcome to **Stage 1** of the **ShopSphere** AWS Architecture Evolution project.

This project demonstrates the progressive evolution of a real-world e-commerce application from a traditional monolithic single-server baseline to a decoupled, multi-tier, auto-scaled, containerized, and Kubernetes-orchestrated cloud architecture on AWS.

---

## 1. Project Objective

The goal of this multi-stage project is to experience firsthand why and how enterprise architectures evolve from monoliths to modern cloud-native systems on AWS:

```
Stage 1: Single EC2 + Local Database (Baseline Monolith)
   ↓
Stage 2: EC2 + Amazon RDS (Database Decoupling)
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

**Stage 1 Scope:** Establish the initial monolithic baseline on a single EC2 instance. All subsequent stages will build directly upon this modular foundation without requiring full rewrites.

---

## 2. Stage 1 Architecture & ASCII Diagram

In Stage 1, the entire monolithic application (web server, application runtime, and database) runs within a single AWS EC2 virtual machine inside a dedicated VPC and public subnet.

```
+=============================================================================+
|                                AWS Cloud                                    |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  | Dedicated VPC (10.0.0.0/16)                                            |  |
|  |                                                                       |  |
|  |   Internet Gateway (0.0.0.0/0)                                        |  |
|  |         |                                                             |  |
|  |         v                                                             |  |
|  |   +---------------------------------------------------------------+   |  |
|  |   | Public Subnet (10.0.1.0/24) - Single Availability Zone         |   |  |
|  |   |                                                               |   |  |
|  |   |   +-------------------------------------------------------+   |   |  |
|  |   |   | EC2 Security Group                                    |   |  |
|  |   |   | Ingress: 80 (HTTP), 443 (HTTPS), 22 (Admin SSH)       |   |  |
|  |   |   | Egress: All Traffic (0.0.0.0/0)                       |   |  |
|  |   |   |                                                       |   |  |
|  |   |   |   +-----------------------------------------------+   |   |  |
|  |   |   |   | ShopSphere EC2 Instance (Amazon Linux 2023)   |   |  |
|  |   |   |   | Public IP: Assign Public IPv4                  |   |  |
|  |   |   |   | IAM Role: AmazonSSMManagedInstanceCore        |   |  |
|  |   |   |   |                                               |   |  |
|  |   |   |   |   [ Port 80 ]                                 |   |  |
|  |   |   |   |       |                                       |   |  |
|  |   |   |   |       v                                       |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |   | Nginx Reverse Proxy                   |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |       | (proxy_pass http://127.0.0.1:8080)    |   |  |
|  |   |   |   |       v                                       |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |   | ShopSphere Monolith (Node.js/Express) |   |  |
|  |   |   |   |   | Listening on :8080 (systemd service)  |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |       | (TCP localhost:5432)                  |   |  |
|  |   |   |   |       v                                       |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |   | PostgreSQL 15 Database (Colocated)    |   |  |
|  |   |   |   |   | Database: shopspheredb                |   |  |
|  |   |   |   |   +---------------------------------------+   |   |  |
|  |   |   |   |                                               |   |  |
|  |   |   |   |   Root EBS Volume (20 GB gp3, Encrypted)      |   |  |
|  |   |   |   +-----------------------------------------------+   |   |  |
|  |   |   +-------------------------------------------------------+   |   |  |
|  |   +---------------------------------------------------------------+   |  |
|  +-----------------------------------------------------------------------+  |
+=============================================================================+
```

---

## 3. Why We Are Starting With a Single EC2 Instance

Starting with a single server provides critical architectural and pedagogical advantages:

1. **Establishes the Baseline Benchmark:** Before introducing distributed systems, we measure latency, throughput, resource consumption, and failure modes on a single server.
2. **Exposes Classic Monolithic Bottlenecks:**
   - **Single Point of Failure (SPOF):** If the EC2 instance fails or reboots, both the store and database are down.
   - **Resource Contention:** Heavy database queries directly rob CPU and RAM from HTTP request handling.
   - **No Horizontal Scalability:** Scaling up requires resizing the instance type (vertical scaling), which incurs downtime.
   - **Coupled Deployments:** Updating application code or database versions impacts the whole server.
3. **Clean Migration Path:** Every subsequent stage solves an explicit pain point identified in Stage 1.

---

## 4. AWS Resources Created

The Stage 1 Terraform configuration provisions the following AWS resources:

| Resource | Type | Purpose |
| :--- | :--- | :--- |
| **VPC** | `aws_vpc` | Isolated virtual network for ShopSphere (`10.0.0.0/16`) |
| **Internet Gateway** | `aws_internet_gateway` | Enables internet ingress and egress for the VPC |
| **Public Subnet** | `aws_subnet` | Subnet in 1 Availability Zone with auto-assigned public IPs (`10.0.1.0/24`) |
| **Route Table & Association** | `aws_route_table` & `aws_route_table_association` | Directs `0.0.0.0/0` outbound traffic to the Internet Gateway |
| **Security Group** | `aws_security_group` | Virtual firewall allowing ports 80 (HTTP), 443 (HTTPS), and 22 (Admin SSH) |
| **IAM Role & Instance Profile** | `aws_iam_role`, `aws_iam_instance_profile` | Attaches `AmazonSSMManagedInstanceCore` for secure Systems Manager console access |
| **EC2 Instance** | `aws_instance` | Runs Amazon Linux 2023, Nginx, Node.js runtime, and PostgreSQL 15 |
| **Encrypted EBS Root Volume** | `root_block_device` | 20 GB `gp3` encrypted block storage |

---

## 5. Network Architecture

- **VPC CIDR:** `10.0.0.0/16` (65,536 private IP addresses available for future multi-tier subnet expansion).
- **Public Subnet:** `10.0.1.0/24` (256 addresses, provisioned in a single Availability Zone).
- **Default Route:** `0.0.0.0/0` forwarded to the attached Internet Gateway (`igw`).
- **Public IP Allocation:** `map_public_ip_on_launch = true` ensures the EC2 instance receives a routable public IPv4 address.
- **Firewall Rules:**
  - Inbound HTTP (80): Open to internet (`0.0.0.0/0`) for web storefront traffic.
  - Inbound HTTPS (443): Open to internet (`0.0.0.0/0`) for future TLS termination.
  - Inbound SSH (22): Restricted to `var.admin_cidr` (e.g. your workstation IP address).
  - Outbound: All egress allowed to fetch packages from AWS Linux repositories and npm.

---

## 6. Application Architecture

- **Technology Stack:** Node.js 20 LTS + Express.js.
- **Internal Port:** `8080`.
- **Reverse Proxy:** Nginx listening on port `80` reverse-proxying requests to `http://127.0.0.1:8080`.
- **Process Management:** Managed via a standard Linux `systemd` unit service (`shopsphere.service`) configured with automatic restarts (`Restart=always`).
- **REST Endpoints:**
  - `GET /` &rarr; Responsive HTML/CSS Storefront UI.
  - `GET /health` &rarr; Live system and database health check JSON.
  - `GET /api/system/info` &rarr; Host metrics, RAM utilization, and runtime details.
  - `GET /api/products` &rarr; Product catalog query.
  - `GET /api/products/:id` &rarr; Individual product details.
  - `GET /api/orders` &rarr; Recent customer orders.
  - `POST /api/orders` &rarr; ACID transactional order placement and inventory deduction.

---

## 7. Database Architecture

- **Engine:** PostgreSQL 15 (locally installed on the same EC2 instance).
- **Database Name:** `shopspheredb`.
- **Database User:** `shopsphere_user`.
- **Connection Host:** `127.0.0.1:5432` (colocated loopback).
- **Schema & Seeding:**
  - `categories`: Product category taxonomy.
  - `products`: Product catalog with live inventory counters (`stock_quantity`).
  - `orders`: Customer orders and payment status.
  - `order_items`: Order line items with historical unit prices.
  - Initial seed data includes 6 sample e-commerce products with stock counts and categories.

> [!NOTE]
> **Secrets Management Note:** For Stage 1, credentials are configured via Terraform input variables and written to the local `/opt/shopsphere/app/.env` file. In **Stage 2** (Amazon RDS) and beyond, secrets will be migrated to **AWS Secrets Manager** with automatic rotation.

---

## 8. Directory Structure

```
shopsphere/
├── app/                                    # ShopSphere Monolith Application Source
│   ├── package.json                        # Node.js dependencies & scripts
│   ├── server.js                           # Express application and PostgreSQL logic
│   ├── .env.example                        # Template environment variables
│   ├── db/
│   │   └── schema.sql                      # DDL schema and seed data
│   └── public/
│       ├── index.html                      # Storefront single-page web app
│       └── styles.css                      # Modern dark-mode UI styling
├── terraform/                              # Modular Terraform Code
│   ├── main.tf                             # Root orchestration & module calls
│   ├── provider.tf                         # AWS provider & default tags
│   ├── variables.tf                        # Root input variable definitions
│   ├── outputs.tf                          # Root output definitions
│   ├── versions.tf                         # Terraform & AWS provider version constraints
│   ├── data.tf                             # Dynamic AMI and Availability Zone lookups
│   ├── terraform.tfvars.example            # Example variable customization values
│   ├── scripts/
│   │   └── user_data.sh.tpl                # Cloud-init bootstrap script template
│   └── modules/
│       ├── vpc/                            # VPC, Subnet, IGW, Route Table module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security-group/                 # Firewall rules module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── ec2/                            # EC2 instance & IAM profile module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── README.md                               # Project documentation (this file)
```

---

## 9. Prerequisites

Before deploying Stage 1, ensure you have:

1. **AWS Account** with administrative permissions for VPC, EC2, and IAM.
2. **AWS CLI** installed and configured (`aws configure` with valid `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`).
3. **Terraform CLI** (v1.5.0 or newer) installed.
4. *(Optional)* An AWS EC2 Key Pair created in your target region if you wish to connect via classic SSH.

---

## 10. Configuration

1. Change directory to `terraform/`:
   ```bash
   cd shopsphere/terraform
   ```

2. Create your `terraform.tfvars` from the example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` to customize settings:
   ```hcl
   aws_region   = "us-east-1"
   project_name = "shopsphere"
   environment  = "stage1"

   # Replace with your workstation's public IP address for SSH security
   admin_cidr   = ["YOUR_PUBLIC_IP/32"]

   # Optional EC2 KeyPair name if you have one in AWS
   ssh_key_name = "my-keypair"

   # Database settings
   db_name      = "shopspheredb"
   db_user      = "shopsphere_user"
   db_password  = "YourStrongPasswordHere123!"
   ```

---

## 11. Terraform Deployment Commands

Run the following commands inside `shopsphere/terraform/`:

```bash
# 1. Format code according to Terraform standards
terraform fmt -recursive

# 2. Initialize provider plugins and modules
terraform init

# 3. Validate syntax and configuration integrity
terraform validate

# 4. Review planned cloud resource creation
terraform plan

# 5. Apply and provision AWS infrastructure
terraform apply
```

Type `yes` when prompted. Terraform will output the public IP and application URL upon completion.

---

## 12. How to Access ShopSphere

Once `terraform apply` finishes, wait approximately 60–90 seconds for the EC2 `user_data` bootstrap script to complete package installation and service startup.

Access the following URLs in your browser or via `curl`:

- **Storefront Web UI:**
  ```
  http://<EC2_PUBLIC_IP>/
  ```
- **Health Check Endpoint:**
  ```
  http://<EC2_PUBLIC_IP>/health
  ```
- **Product Catalog API:**
  ```
  http://<EC2_PUBLIC_IP>/api/products
  ```
- **System Architecture & Memory Info:**
  ```
  http://<EC2_PUBLIC_IP>/api/system/info
  ```

---

## 13. How to SSH into the Instance

### Method A: AWS Systems Manager Session Manager (Recommended & Secure)
Because the EC2 instance is launched with an IAM instance profile containing `AmazonSSMManagedInstanceCore`, you can connect securely without exposing port 22 or managing SSH keys:

```bash
aws ssm start-session --target <EC2_INSTANCE_ID>
```

### Method B: Standard SSH (Requires Key Pair)
If you specified `ssh_key_name` in `terraform.tfvars` and permitted your IP in `admin_cidr`:

```bash
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

---

## 14. How to Troubleshoot Application Startup

If the web page does not load immediately, SSH into the instance or use SSM Session Manager and inspect the system logs:

1. **Check Cloud-Init / User-Data Execution Log:**
   ```bash
   sudo cat /var/log/user-data.log
   ```
2. **Check ShopSphere Application Service Status & Logs:**
   ```bash
   sudo systemctl status shopsphere.service
   sudo journalctl -u shopsphere.service -n 50 -f
   ```
3. **Check PostgreSQL Database Status:**
   ```bash
   sudo systemctl status postgresql.service
   sudo -u postgres psql -d shopspheredb -c "\dt"
   ```
4. **Check Nginx Status and Access/Error Logs:**
   ```bash
   sudo systemctl status nginx.service
   sudo tail -f /var/log/nginx/error.log
   ```
5. **Test Local HTTP Response on Port 8080:**
   ```bash
   curl -i http://127.0.0.1:8080/health
   ```

---

## 15. How to Destroy the Infrastructure

When you are finished testing Stage 1, clean up and remove all provisioned AWS resources to avoid unnecessary cloud costs:

```bash
cd shopsphere/terraform
terraform destroy
```

Type `yes` when prompted. Terraform will terminate the EC2 instance, delete the security group, route table, subnet, internet gateway, and VPC.
