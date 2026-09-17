# ShopSphere — Stage 9: Amazon EKS & Microservices Progressive Migration

## 1. Executive Summary

Stage 9 implements a **zero-downtime progressive migration** from the Stage 8 Dockerized Monolith (running on an EC2 Auto Scaling Group) to a cloud-native microservices architecture on **Amazon Elastic Kubernetes Service (EKS)**.

### Key Architectural Tenets
1. **Parallel Coexistence**: Stage 8 (Blue) remains 100% operational, healthy, and serving live traffic throughout the migration.
2. **Dual-Target Ingress**: The existing Application Load Balancer (ALB) routes traffic between the Stage 8 ASG Target Group and the Stage 9 EKS Target Group via weighted and path-based listener rules.
3. **Decomposed Business Microservices**:
   - **Product Service** (`8081`): Product catalog, read operations, Redis caching, RDS storage.
   - **Order Service** (`8082`): Order placement, transactional RDS storage, asynchronous Amazon SQS event dispatch.
   - **User Service** (`8083`): Authentication and customer profiles.
   - **Monolith Compatibility Workload** (`8080`): Reference deployment of the Stage 8 container running on EKS.
4. **Automated Rollback**: Immediate 1-click fallback resets ALB listener rules back to 100% Blue (Stage 8) if any metric or probe degrades.

---

## 2. Architecture Diagram

```
                                 Users / Internet
                                        │
                                        ▼
                               AWS CloudFront (CDN)
                                        │
                                        ▼
                                   AWS WAF ACL
                                        │
                                        ▼
                        Application Load Balancer (ALB)
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 │                                             │
      Path: /* (Default / Fallback)              Path: /api/products*, /api/orders*
      Weighted: Blue (100% ➔ 0%)                 Weighted: Green (0% ➔ 100%)
                 │                                             │
                 ▼                                             ▼
       Stage 8 Target Group                          Stage 9 Target Group
        (Instance / ASG)                                (IP / Pods)
                 │                                             │
                 ▼                                             ▼
        EC2 Auto Scaling Group                          Amazon EKS Cluster
                 │                               (Managed Multi-AZ Node Group)
                 ▼                                             │
       Dockerized Monolith                ┌────────────────────┼────────────────────┐
      (Port 8080, UID 10001)              ▼                    ▼                    ▼
                                    Product Service       Order Service        User Service
                                      (Port 8081)          (Port 8082)          (Port 8083)
                                          │                    │                    │
                 ┌────────────────────────┴────────────────────┴────────────────────┘
                 │ Shared Data & Messaging Layer
                 ▼
       ┌───────────────────┬───────────────────┬───────────────────┐
       ▼                   ▼                   ▼                   ▼
  Amazon RDS          ElastiCache         Amazon SQS          AWS Lambda
(PostgreSQL 15)      Redis Cluster      Order Processing    Worker Function
```

---

## 3. Directory Structure

```text
stage-9/
├── terraform/
│   ├── modules/
│   │   ├── eks/                      # EKS Cluster, OIDC provider, cluster SG
│   │   ├── node-group/               # Managed Multi-AZ Node Group, launch template
│   │   ├── iam/                      # IRSA roles (ALB controller, SQS publisher)
│   │   ├── alb-routing/              # Stage 9 Target Group, weighted & path listener rules
│   │   └── ecr/                      # ECR repositories for microservices
│   ├── main.tf                       # Module orchestration & Stage 8 data references
│   ├── variables.tf                  # Environment & sizing parameters
│   ├── outputs.tf                    # Cluster endpoint, kubeconfig, target group ARNs
│   ├── provider.tf                   # AWS & TLS providers
│   └── terraform.tfvars.example      # Example variable values
│
├── kubernetes/
│   ├── namespaces/                   # Namespace 'shopsphere-stage9'
│   ├── configmaps/                   # DB, Redis, SQS, Region configuration
│   ├── secrets/                      # Encrypted DB credentials reference
│   ├── monolith/                     # Reference workload deployment on EKS
│   ├── product-service/              # Product service Deployment, Service, HPA
│   ├── order-service/                # Order service Deployment, Service, IRSA, HPA
│   ├── user-service/                 # User service Deployment, Service, HPA
│   └── ingress/                      # Ingress & TargetGroupBinding manifests
│
├── services/
│   ├── product/                      # Product Microservice (Express + Redis + Postgres)
│   ├── order/                        # Order Microservice (Express + SQS + Postgres)
│   └── user/                         # User Microservice (Express + Postgres)
│
├── scripts/
│   ├── deploy.sh                     # Orchestrates kubectl apply & rollouts
│   ├── health-check.sh               # Probes pods, endpoints, and database/cache
│   ├── migrate-traffic.sh            # Progressively shifts ALB weights (10/25/50/75/100)
│   └── rollback.sh                   # Emergency 1-click fallback to Stage 8 ASG
│
├── security/
│   ├── sast/                         # Semgrep scanning configuration
│   ├── sca/                          # Trivy filesystem dependency scan
│   ├── iac/                          # Checkov CIS Terraform policy scan
│   └── dast/                         # OWASP ZAP baseline scan configuration
│
├── Jenkinsfile-infra                 # Dedicated Jenkins Infrastructure Pipeline (EKS)
├── Jenkinsfile-app                   # Dedicated Jenkins Application Pipeline (EKS Deploy + Migration)
└── README.md                         # Complete documentation
```

---

## 4. Microservices Breakdown

| Service | Port | Database / Cache | External AWS Services | Path Routing Rule |
| :--- | :--- | :--- | :--- | :--- |
| **Product Service** | `8081` | RDS PostgreSQL (`products` table) + ElastiCache Redis | None | `/api/products*` |
| **Order Service** | `8082` | RDS PostgreSQL (`orders` table) | Amazon SQS (`SendMessage`) | `/api/orders*` |
| **User Service** | `8083` | RDS PostgreSQL (`users` table) | None | `/api/users*` |
| **Monolith Workload** | `8080` | Shared RDS + Redis | SQS + Lambda | `/*` (Fallback) |

---

## 5. Progressive Migration Flow

### Step 1: Infrastructure Provisioning (Zero Traffic Shift)
Run the dedicated **`Jenkinsfile-infra`** pipeline:
```bash
# Deploys EKS cluster, node groups, ECR repos, and Stage 9 Target Groups.
# Initial traffic remains: Blue (Stage 8) = 100%, Green (Stage 9) = 0%.
```

### Step 2: Microservices Build & Deployment to EKS
Run the dedicated **`Jenkinsfile-app`** pipeline with parameter:
```text
MIGRATION_WEIGHT = "100-0 (Test Green 0%)"
```
* Builds Docker images with immutable tags: `v9.${BUILD_NUMBER}-${GIT_COMMIT}`.
* Scans images with Trivy.
* Deploys to EKS namespace `shopsphere-stage9`.
* Runs internal health checks.

### Step 3: Canary Traffic Shift
In `Jenkinsfile-app` (or via `./stage-9/scripts/migrate-traffic.sh`):
```bash
./stage-9/scripts/migrate-traffic.sh weight 90 10
```
* 10% of general traffic reaches Stage 9 EKS; 90% stays on Stage 8 ASG.

### Step 4: Path-Based Microservices Cutover
```bash
./stage-9/scripts/migrate-traffic.sh path-product enable
./stage-9/scripts/migrate-traffic.sh path-order enable
```
* 100% of `/api/products*` is handled by the high-performance EKS Product microservice with sub-millisecond Redis caching.
* 100% of `/api/orders*` is handled by the EKS Order microservice with direct SQS message publishing via IRSA.

### Step 5: Final Balanced Migration
Progressively advance weights:
```bash
./stage-9/scripts/migrate-traffic.sh weight 50 50
./stage-9/scripts/migrate-traffic.sh weight 0 100
```
Once `0 100` is active and validated, all traffic is served by the EKS microservices cluster.

---

## 6. Instant Emergency Rollback

If any unexpected error occurs, execute:
```bash
./stage-9/scripts/rollback.sh
```
This single command instantly:
1. Reverts ALB listener rule weight back to **100% Blue (Stage 8)** and **0% Green (Stage 9)**.
2. Removes path-based overrides so all traffic routes to the proven Stage 8 ASG.
3. Checks target health on the Stage 8 instances to confirm recovery.

---

## 7. Deployment Commands

### Infrastructure Deployment (Manual CLI or Jenkins)
```bash
cd stage-9/terraform
terraform init
terraform plan -var="environment=stage9"
terraform apply -auto-approve -var="environment=stage9"
```

### Application Workloads Deployment
```bash
# 1. Update local kubeconfig
aws eks update-kubeconfig --region us-east-1 --name shopsphere-stage9-eks

# 2. Deploy workloads
chmod +x stage-9/scripts/*.sh
./stage-9/scripts/deploy.sh "shopsphere-stage9-eks" "latest"

# 3. Health verification
./stage-9/scripts/health-check.sh
```
