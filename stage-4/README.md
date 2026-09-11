# ShopSphere: Cloud Architecture Evolution

## Stage 4: Amazon ElastiCache / Redis (In-Memory Caching & Session Management)

Welcome to **Stage 4** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we enhance our highly available compute tier (Stage 3) by introducing **Amazon ElastiCache for Redis** inside dedicated private cache subnets. By adopting an **in-memory Cache-Aside pattern**, ShopSphere slashes product catalog response times from ~10ms down to sub-millisecond levels (< 1ms) while shielding our Amazon RDS PostgreSQL database from read saturation.

---

## 1. Stage 4 Objective & Evolution Path

```
Stage 1: Single EC2 + Local Database (Baseline Monolith)
   ↓
Stage 2: EC2 + Amazon RDS PostgreSQL (Database Decoupling)
   ↓
Stage 3: ALB + Auto Scaling Group + Multi-EC2 (Horizontal Scaling & High Availability)
   ↓
[ CURRENT ] Stage 4: Amazon ElastiCache / Redis (In-Memory Caching & Session Management)
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

### What Problem Are We Solving from Stage 3?
In Stage 3, we successfully scaled the compute tier horizontally with an Auto Scaling Group and ALB. However, as the number of EC2 instances and concurrent shoppers increases:
- **Database Read Bottleneck:** Over 90% of e-commerce traffic consists of repetitive read queries (browsing catalog, viewing product details). Having every EC2 instance query PostgreSQL directly results in unnecessary disk I/O and connection pool exhaustion.
- **Query Latency:** Even an optimized relational database query requires network round-trips, query parsing, and table scans resulting in typical latencies of 5ms to 20ms.
- **Cost Inefficiency:** Scaling relational database compute (larger RDS instances) to handle read-heavy traffic is significantly more expensive than introducing an in-memory caching layer.

**Stage 4 resolves this by introducing Amazon ElastiCache Redis**, enabling ultra-low-latency in-memory data retrieval with automatic cache invalidation on catalog mutations.

---

## 2. Stage 4 Architecture Diagram

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
|  |   | Security Group: 80/HTTP, 443/HTTPS from 0.0.0.0/0                                                    |   |  |
|  |   +-----------------------------------------------------------------------------------------------------+   |  |
|  |         |                                                           |                                       |  |
|  |         | HTTP (Round-Robin)                                        | HTTP (Round-Robin)                    |  |
|  |         v                                                           v                                       |  |
|  |   +-----------------------------------------+   +-----------------------------------------+                 |  |
|  |   | Public Subnet 1: 10.0.1.0/24 (AZ-A)     |   | Public Subnet 2: 10.0.2.0/24 (AZ-B)     |                 |  |
|  |   |                                         |   |                                         |                 |  |
|  |   |  +-----------------------------------+  |   |  +-----------------------------------+  |                 |  |
|  |   |  | EC2 Instance 1 (Auto Scaling Group)|  |   |  | EC2 Instance 2 (Auto Scaling Group)|  |                 |  |
|  |   |  | SG: Port 80 from ALB SG ONLY      |  |   |  | SG: Port 80 from ALB SG ONLY      |  |                 |  |
|  |   |  | Node.js App + Nginx Reverse Proxy |  |   |  | Node.js App + Nginx Reverse Proxy |  |                 |  |
|  |   |  +-----------------------------------+  |   |  +-----------------------------------+  |                 |  |
|  |   +-----------------------------------------+   +-----------------------------------------+                 |  |
|  |         |               |                                           |               |                       |  |
|  |         | TCP 6379      | TCP 5432                                  | TCP 6379      | TCP 5432              |  |
|  |         |               \---------------------------\   /-----------/               |                       |  |
|  |         |                                            \ /                            |                       |  |
|  |         v                                             v                             v                       |  |
|  |   +---------------------------------------------+   +---------------------------------------------+         |  |
|  |   | Private Cache Subnets (AZ-A & AZ-B)         |   | Private DB Subnets (AZ-A & AZ-B)            |         |  |
|  |   | Subnet 1: 10.0.20.0/24 | Subnet 2: 10.0.21/24 | Subnet 1: 10.0.10.0/24 | Subnet 2: 10.0.11/24 |         |  |
|  |   |                                             |   |                                             |         |  |
|  |   | +-----------------------------------------+ |   | +-----------------------------------------+ |         |  |
|  |   | | Amazon ElastiCache Redis 7              | |   | | Amazon RDS PostgreSQL 15                | |         |  |
|  |   | | Subnet Group + Parameter Group (LRU)    | |   | | gp3 Encrypted Storage, Multi-AZ Subnets | |         |  |
|  |   | | Endpoint: shopsphere-stage4-redis...    | |   | | Endpoint: shopsphere-stage4-postgres... | |         |  |
|  |   | | Port: 6379 (from EC2 SG ONLY)           | |   | | Port: 5432 (from EC2 SG ONLY)           | |         |  |
|  |   | +-----------------------------------------+ |   | +-----------------------------------------+ |         |  |
|  |   +---------------------------------------------+   +---------------------------------------------+         |  |
|  +-------------------------------------------------------------------------------------------------------------+  |
+===================================================================================================================+
```

---

## 3. How Caching Works in Stage 4: Cache-Aside Pattern

ShopSphere implements the industry-standard **Cache-Aside (Lazy-Loading)** pattern with **write-through invalidation**:

```
Client Request (GET /api/products)
         |
         v
1. Check Redis Cache (`shopsphere:products:all`)
         |
    +----+--------------------------------+
    |                                     |
    v (Found)                             v (Not Found)
[ CACHE HIT ]                         [ CACHE MISS ]
Return cached data in < 1ms           Query PostgreSQL Database (~8-15ms)
X-Cache: HIT                               |
                                      Store in Redis with 60s TTL
                                           |
                                      Return DB data & X-Cache: MISS
```

### Automatic Cache Invalidation on Order Mutations:
When a customer places an order (`POST /api/orders`), the application executes an ACID transaction in PostgreSQL to reserve stock. Immediately after committing the transaction, the server **purges** the affected cache keys (`shopsphere:products:all` and `shopsphere:product:${id}`). The next catalog read guarantees fresh, consistent stock levels without stale inventory issues.

---

## 4. AWS Resources Provisioned

| Resource | Terraform Type | Purpose |
| :--- | :--- | :--- |
| **VPC** | `aws_vpc` | Virtual network (`10.0.0.0/16`) with DNS hostnames enabled |
| **Public Subnets** (x2) | `aws_subnet` | Subnets in AZ-A (`10.0.1.0/24`) and AZ-B (`10.0.2.0/24`) for ALB & ASG |
| **Private DB Subnets** (x2) | `aws_subnet` | Dedicated subnets in AZ-A (`10.0.10.0/24`) and AZ-B (`10.0.11.0/24`) for RDS |
| **Private Cache Subnets** (x2) | `aws_subnet` | Dedicated subnets in AZ-A (`10.0.20.0/24`) and AZ-B (`10.0.21.0/24`) for ElastiCache |
| **ALB Security Group** | `aws_security_group` | Ingress: 80, 443 from `0.0.0.0/0` |
| **EC2 ASG Security Group** | `aws_security_group` | Ingress: 80 strictly from `alb_sg`; 22 from `admin_cidr` |
| **RDS Security Group** | `aws_security_group` | Ingress: 5432 strictly from `ec2_sg` |
| **ElastiCache Security Group** | `aws_security_group` | Ingress: 6379 strictly from `ec2_sg` |
| **Application Load Balancer** | `aws_lb` | High-availability layer-7 load balancer |
| **ALB Target Group & Listener** | `aws_lb_target_group`, `aws_lb_listener` | Probes `/health` every 15s and forwards traffic |
| **Launch Template & ASG** | `aws_launch_template`, `aws_autoscaling_group` | EC2 fleet (Min 2, Desired 2, Max 4) across multi-AZ |
| **Scaling Policy** | `aws_autoscaling_policy` | Target tracking scaling on average CPU utilization (70%) |
| **Amazon RDS Instance** | `aws_db_instance` | PostgreSQL 15 managed engine, encrypted gp3 storage |
| **ElastiCache Subnet Group** | `aws_elasticache_subnet_group` | Multi-AZ subnet group for Redis cluster |
| **ElastiCache Parameter Group** | `aws_elasticache_parameter_group` | Custom Redis 7 configuration with `volatile-lru` eviction policy |
| **ElastiCache Redis Cluster** | `aws_elasticache_cluster` | In-memory Redis engine node |

---

## 5. Directory Structure

```
stage-4/
├── app/                                    # ShopSphere Stage 4 Application Source
│   ├── package.json                        # Node.js dependencies (v4.0.0, includes redis client)
│   ├── server.js                           # Express app with Redis Cache-Aside & metrics
│   ├── .env.example                        # Template with DB and Redis environment variables
│   ├── db/
│   │   └── schema.sql                      # Idempotent PostgreSQL schema and seed catalog
│   └── public/
│       ├── index.html                      # Storefront UI with real-time Cache Dashboard
│       └── styles.css                      # Modern dark theme styles with cache visualizers
├── terraform/                              # Stage 4 Modular Terraform Code
│   ├── main.tf                             # Root orchestration tying all 6 modules
│   ├── provider.tf                         # AWS provider definition with default tags
│   ├── variables.tf                        # Root variables (VPC, ASG, RDS, ElastiCache)
│   ├── outputs.tf                          # ALB DNS, RDS endpoint, Redis endpoint, test commands
│   ├── versions.tf                         # Provider constraints
│   ├── data.tf                             # Dynamic AMI and Availability Zone discovery
│   ├── terraform.tfvars.example            # Sample configuration values
│   ├── scripts/
│   │   └── user_data.sh.tpl                # Cloud-init bootstrap configuring RDS & Redis
│   └── modules/
│       ├── vpc/                            # Multi-tier VPC (Public, Private DB, Private Cache)
│       ├── security-group/                 # Tiered Security Groups (ALB, EC2, RDS, ElastiCache)
│       ├── alb/                            # Application Load Balancer & Target Group
│       ├── asg/                            # Auto Scaling Group & Launch Template
│       ├── rds/                            # Amazon RDS PostgreSQL 15
│       └── elasticache/                    # Amazon ElastiCache Redis 7 Module
├── Jenkinsfile                             # Dedicated Jenkins pipeline for Stage 4
└── README.md                               # Stage 4 Documentation
```

---

## 6. Deployment Guide

### Option A: Deploy via Terraform CLI

#### Step 1: Navigate to the Stage 4 Terraform Directory
```bash
cd /vagrant/dev_projects/shopsphere-aws-scaling/stage-4/terraform
```

#### Step 2: Configure Input Variables
Create `terraform.tfvars` from the template:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Customize settings in `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
project_name = "shopsphere"
environment  = "stage4"

# Restrict SSH access
admin_cidr   = ["YOUR_PUBLIC_IP/32"]

# Auto Scaling Group Fleet Sizing
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4

# RDS database settings
db_name      = "shopspheredb"
db_user      = "shopsphere_user"
db_password  = "YourSuperSecretStrongPassword123!"

# ElastiCache Redis settings
cache_node_type      = "cache.t3.micro"
redis_engine_version = "7.1"
redis_port           = 6379
```

#### Step 3: Initialize Terraform
```bash
terraform init
```

#### Step 4: Validate Configuration
```bash
terraform validate
```

#### Step 5: Plan & Apply
```bash
terraform plan
terraform apply
```
Type `yes` when prompted. Terraform will provision the 3-tier VPC, security groups, ALB, RDS database, ElastiCache Redis cluster, and Auto Scaling fleet.

---

### Option B: Deploy via Jenkins Pipeline

You can deploy Stage 4 automatically using either:
1. **Dedicated Pipeline:** Point a Jenkins pipeline job to `stage-4/Jenkinsfile`.
2. **Root Multi-Stage Pipeline:** Run the root `Jenkinsfile`, select `STAGE = stage-4`, choose `ACTION = apply`, and trigger the build.

#### Required Jenkins Plugins
- **Pipeline** (`workflow-aggregator`)
- **Git** (`git`)
- **AnsiColor** (`ansicolor`) *(Required for `ansiColor('xterm')`)*
- **Pipeline: Input Step** (`pipeline-input-step`)

#### Jenkins Host Permissions
Ensure Docker is running and Jenkins user has Docker access:
```bash
sudo usermod -aG docker jenkins && sudo systemctl restart jenkins
```

---

## 7. Testing & Verifying Cache Performance

Once deployed, access the Application Load Balancer DNS name:
```
http://<alb_dns_name>
```

### 1. Test Cold vs. Warm Latency via cURL

Run this command to test the first request (Cold Cache):
```bash
curl -i -s "http://<alb_dns_name>/api/products" | grep -E 'X-Cache|latencyMs|source'
```
**Output (Cold Cache):**
```http
X-Cache: MISS
X-Cache-Latency: 12ms
"source":"database","dbEngine":"Amazon RDS PostgreSQL","latencyMs":12
```

Now execute the exact same query immediately:
```bash
curl -i -s "http://<alb_dns_name>/api/products" | grep -E 'X-Cache|latencyMs|source'
```
**Output (Warm Cache - Sub-Millisecond!):**
```http
X-Cache: HIT
X-Cache-Latency: 0ms
"source":"cache","cacheEngine":"Amazon ElastiCache Redis","latencyMs":0
```

### 2. Live Storefront Cache Dashboard
Open the storefront in your browser:
- Observe the **Cache Hit Ratio** and **Last Query Latency** indicators update in real-time.
- Click **"Query Catalog"** multiple times to watch the hit ratio rise to 90%+.
- Click **"Flush Redis Cache (Cold Test)"** to purge Redis and observe a transient cache miss followed immediately by lightning-fast cache hits.

### 3. Verify Cache Invalidation on Order Placement
1. Add an item to your cart and click **Confirm & Place Order**.
2. Notice the alert: `Order placed! Stored in RDS & Redis cache invalidated`.
3. The next catalog load will query PostgreSQL to refresh stock, re-populate Redis with fresh data, and reset the cache TTL automatically.

### 4. Inspect Redis Cache Statistics Endpoint
```bash
curl -s "http://<alb_dns_name>/api/cache/stats" | jq .
```
```json
{
  "success": true,
  "redisConnected": true,
  "hitRatioPercent": 88.5,
  "hits": 23,
  "misses": 3,
  "cachedKeysCount": 2,
  "cachedKeys": [
    "shopsphere:products:all",
    "shopsphere:product:1"
  ]
}
```

---

## 8. Teardown Instructions

```bash
cd /vagrant/dev_projects/shopsphere-aws-scaling/stage-4/terraform
terraform destroy
```
Type `yes` when prompted. All AWS resources (ElastiCache, RDS, ALB, ASG, VPC) will be cleanly destroyed.
