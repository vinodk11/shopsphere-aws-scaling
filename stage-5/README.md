# ShopSphere: Cloud Architecture Evolution

## Stage 5: Amazon SQS + AWS Lambda (Decoupled Asynchronous Order Processing)

Welcome to **Stage 5** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we transition ShopSphere from a synchronous processing model to a modern **event-driven decoupled architecture**. By introducing **Amazon SQS** as an asynchronous message buffer and **AWS Lambda** as an elastic serverless worker, ShopSphere achieves non-blocking checkouts (sub-20ms HTTP 202 Accepted responses), eliminates checkout bottlenecks, isolates failures, and automates DLQ error handling.

---

## 1. Stage 5 Objective & Evolution Path

```
Stage 1  → Monolith + EC2
Stage 2  → RDS PostgreSQL (Database Decoupling)
Stage 3  → ALB + Auto Scaling Group (Horizontal Scaling & High Availability)
Stage 4  → Redis / ElastiCache (In-Memory Caching & Session Management)
[ CURRENT ] Stage 5  → SQS + Lambda (Decoupled Asynchronous Order Processing)
Stage 6  → CloudFront + WAF (Global Edge CDN & Web Security)
Stage 7  → DevSecOps (SAST, DAST, SCA, Secrets Detection, Image Scanning, Pipeline Security)
Stage 8  → Docker (Containerization & Multi-Stage Builds)
Stage 9  → EKS (Kubernetes Container Orchestration & Microservices)
Stage 10 → GitOps / Argo CD (Continuous Delivery & Full Observability)
```

### What Problem Are We Solving from Stage 4?
In Stage 4, ShopSphere scaled reads efficiently through ElastiCache Redis and compute through ALB + ASG. However, **order checkout was still synchronous and tightly coupled**:
- **Checkout Latency:** Placing an order required the EC2 instance to execute database writes, payment gateway communication, inventory reserve, invoice generation, and email dispatch within a single blocking HTTP request (taking 800ms – 2500ms).
- **Blast Radius & Cascade Failures:** If a downstream payment gateway, notification service, or warehouse API experienced slowness or an outage, customer checkout threads would hang, exhausting EC2 connection pools and causing cascading system downtime.
- **Traffic Spikes & Throttling:** During flash sales, surges in checkout requests could overwhelm database connection limits and drop transactions.

### How Stage 5 Solves This:
By introducing **Amazon SQS** and **AWS Lambda**:
1. **Instant Response (HTTP 202 Accepted):** The EC2 web tier validates items, reserves stock, writes an initial `PENDING` order to RDS, publishes an `ORDER_CREATED` event to Amazon SQS, and returns within `< 20ms`.
2. **Elastic Serverless Scaling:** AWS Lambda polls SQS, scales automatically based on queue depth, and processes fulfillment workflows independently of EC2.
3. **Fault Isolation with Dead Letter Queue (DLQ):** Unprocessed or malformed messages are safely captured in a dedicated DLQ after 3 retries without losing customer data or blocking subsequent orders.

---

## 2. Stage 5 Architecture Diagram

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
|  |   |  | - Node.js App + Nginx Proxy       |  |   |  | - Node.js App + Nginx Proxy       |  |                 |  |
|  |   |  | - IAM Role: sqs:SendMessage       |  |   |  | - IAM Role: sqs:SendMessage       |  |                 |  |
|  |   |  +-----------------------------------+  |   |  +-----------------------------------+  |                 |  |
|  |   +-----------------------------------------+   +-----------------------------------------+                 |  |
|  |         |             |            \                             /            |             |                   |  |
|  |         | TCP 6379    | TCP 5432    \                           /             | TCP 5432    | TCP 6379          |  |
|  |         |             |              \                         /              |             |                   |  |
|  |         |             |               \                       /               |             |                   |  |
|  |         v             v                \                     /                v             v                   |  |
|  |   +-------------+ +-------------+       +-------------------+       +-------------+ +-------------+             |  |
|  |   | ElastiCache | | Amazon RDS  |<------| (Write PENDING)   |------>| Amazon RDS  | | ElastiCache |             |  |
|  |   | Redis 7     | | PostgreSQL  |       +-------------------+       | PostgreSQL  | | Redis 7     |             |  |
|  |   +-------------+ +-------------+                                   +-------------+ +-------------+             |  |
|  |                                                                                                             |  |
|  +-------------------------------------------------------------------------------------------------------------+  |
|                                                              |                                                    |
|                                                              | HTTPS (Publish ORDER_CREATED event)                |
|                                                              v                                                    |
|                                         +------------------------------------------+                              |
|                                         | Amazon SQS: Main Order Queue             |                              |
|                                         | shopsphere-stage5-order-processing-queue |                              |
|                                         | - SSE-SQS Server-Side Encryption         |                              |
|                                         | - Visibility Timeout: 60s                |                              |
|                                         | - Message Retention: 4 days              |                              |
|                                         +------------------------------------------+                              |
|                                                   |                      |                                        |
|                                                   | Event Source Mapping | Max Receives > 3                       |
|                                                   | (Batch Size: 10)     | (Redrive Policy)                       |
|                                                   v                      v                                        |
|                                    +------------------------------+  +-----------------------------------------+  |
|                                    | AWS Lambda Function Worker   |  | Amazon SQS: Dead Letter Queue (DLQ)     |  |
|                                    | shopsphere-order-processor   |  | shopsphere-stage5-order-processing-dlq  |  |
|                                    | - Runtime: Node.js 20.x      |  | - Retention: 14 days                    |  |
|                                    | - Memory: 256MB              |  | - Poison pill isolation & diagnostics   |  |
|                                    | - Partial Batch Failures     |  +-----------------------------------------+  |
|                                    +------------------------------+                                               |
|                                        |                      |                                                   |
|                                        |                      |                                                   |
|                                        v                      v                                                   |
|                         +--------------------------+  +-----------------------------+                             |
|                         | Amazon CloudWatch Logs   |  | Amazon RDS PostgreSQL 15    |                             |
|                         | Structured JSON Auditing |  | Status: PENDING -> FULFILLED|                             |
|                         +--------------------------+  +-----------------------------+                             |
+===================================================================================================================+
```

---

## 3. Asynchronous Order Processing Flow

```
1. Customer initiates Checkout (POST /api/orders)
              │
              ▼
2. Web App reserves inventory & saves order in RDS (Status: PENDING)
              │
              ▼
3. Web App publishes event to Amazon SQS Queue (< 5ms)
              │
              ▼
4. Web App returns HTTP 202 Accepted to customer (< 20ms total latency)
   Customer browser displays real-time fulfillment tracker

──────────────────────── [ ASYNCHRONOUS BOUNDARY ] ────────────────────────

5. Amazon SQS buffers message with server-side encryption
              │
              ▼
6. AWS Lambda Event Source Mapping polls SQS batch (1-10 records)
              │
              ▼
7. AWS Lambda Worker Execution:
   ├─ Deserializes JSON & validates order structure
   ├─ Assesses fraud risk score (< 20: Approved)
   ├─ Simulates payment capture gateway settlement
   ├─ Allocates warehouse dispatch fulfillment reference
   ├─ Updates Amazon RDS order status to FULFILLED
   └─ Emits structured JSON audit trail to AWS CloudWatch Logs
              │
              ├─ SUCCESS: Lambda acknowledges; SQS deletes message
              └─ FAILURE: Retries up to 3 times; SQS routes poison message to DLQ
```

### Realistic Order Event Payload
Messages published to the SQS queue follow a standard event structure:

```json
{
  "eventType": "ORDER_CREATED",
  "orderId": 1042,
  "customerId": 456,
  "customerName": "Alice Johnson",
  "customerEmail": "alice@example.com",
  "shippingAddress": "742 Evergreen Terrace, Springfield, OR",
  "totalAmount": "249.99",
  "items": [
    {
      "productId": 2,
      "name": "ShopSphere Apex Smart Watch",
      "quantity": 1,
      "unitPrice": 249.99
    }
  ],
  "timestamp": "2026-09-11T12:00:00.000Z",
  "ingestedByHost": "ip-10-0-1-45.ec2.internal"
}
```

---

## 4. Terraform & Component Specifications

### A. Amazon SQS Queues (`modules/sqs`)
| Resource | Parameter | Value | Description |
| :--- | :--- | :--- | :--- |
| **Main Queue** | Name | `shopsphere-${environment}-order-processing-queue` | Primary ingestion queue |
| | Visibility Timeout | `60 seconds` | Time message is hidden while Lambda processes (must exceed Lambda timeout) |
| | Message Retention | `345600 seconds` (4 days) | Time SQS retains unprocessed messages |
| | Server-Side Encryption | `SSE-SQS` (AES-256) | Zero-cost default encryption |
| | Redrive Policy | `maxReceiveCount = 3` | Moves message to DLQ after 3 failed attempts |
| **Dead Letter Queue** | Name | `shopsphere-${environment}-order-processing-dlq` | Captures poison messages |
| | Message Retention | `1209600 seconds` (14 days) | Extended retention for operational triage |
| | Redrive Allow Policy | `byQueue` (Scoped to Main Queue) | Restricts DLQ enrollment |

### B. AWS Lambda Serverless Worker (`modules/lambda`)
| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Runtime** | `nodejs20.x` | Modern active LTS Node.js runtime |
| **Source Directory** | `stage-5/lambda` | Packaged using `data.archive_file` |
| **Handler** | `index.handler` | Main entrypoint |
| **Memory Size** | `256 MB` | Fast execution with optimal vCPU allocation |
| **Timeout** | `30 seconds` | Max processing window per batch |
| **Batch Size** | `10` | Number of messages pulled per invocation |
| **Batching Window** | `5 seconds` | Allows batch accumulation during low load |
| **Failure Reporting** | `ReportBatchItemFailures` | Only retries failed records instead of re-processing entire batch |
| **CloudWatch Logs** | `/aws/lambda/shopsphere-${environment}-order-processor` | 14-day log retention |

### C. Least-Privilege IAM Architecture (`modules/iam`)
- **EC2 ASG Role (`shopsphere-${environment}-ec2-asg-role`):**
  - `AmazonSSMManagedInstanceCore`: AWS Systems Manager Session Manager access without open SSH ports.
  - SQS Publisher Policy: `sqs:SendMessage`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes` strictly restricted to `shopsphere-${environment}-order-processing-queue`.
- **Lambda Role (`shopsphere-${environment}-lambda-worker-role`):**
  - `AWSLambdaBasicExecutionRole`: CloudWatch log stream and event creation.
  - SQS Consumer Policy: `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`, `sqs:ChangeMessageVisibility` scoped to the main queue ARN.

---

## 5. Repository Directory Structure

```
stage-5/
├── Jenkinsfile                          # CI/CD pipeline with Terraform automation & smoke tests
├── README.md                            # Comprehensive architectural documentation
├── app/                                 # ShopSphere Node.js web application
│   ├── .env.example                     # Environment configuration template
│   ├── package.json                     # Dependencies (@aws-sdk/client-sqs, pg, redis, express)
│   ├── server.js                        # Express server with async SQS publishing & cache-aside
│   ├── db/
│   │   └── schema.sql                   # Database schema with PENDING/FULFILLED order lifecycle
│   └── public/
│       ├── index.html                   # UI with live SQS event pipeline visualizer
│       └── styles.css                   # Responsive layout and order status badge styles
├── lambda/                              # AWS Lambda Serverless Worker code
│   ├── index.js                         # SQS consumer, fraud check, payment capture, fulfillment
│   └── package.json                     # Lambda metadata & test runner
└── terraform/                           # Complete Infrastructure-as-Code definitions
    ├── data.tf                          # AMI & AZ lookups
    ├── main.tf                          # Root module orchestration
    ├── outputs.tf                       # Exposed infrastructure endpoints & queue URLs
    ├── provider.tf                      # AWS provider configuration
    ├── terraform.tfvars.example         # Variable assignment template
    ├── variables.tf                     # Input variable declarations
    ├── versions.tf                      # Required terraform & provider constraints
    ├── scripts/
    │   └── user_data.sh.tpl             # EC2 cloud-init script injecting SQS & RDS parameters
    └── modules/
        ├── alb/                         # Application Load Balancer & HTTP listeners
        ├── asg/                         # Auto Scaling Group & Launch Template
        ├── elasticache/                 # Amazon ElastiCache Redis cluster
        ├── iam/                         # Dedicated least-privilege IAM roles for EC2 & Lambda
        ├── lambda/                      # Lambda function, event source mapping & log groups
        ├── rds/                         # Amazon RDS PostgreSQL 15 instance
        ├── security-group/              # Multi-tier firewalls (ALB, EC2, RDS, ElastiCache)
        ├── sqs/                         # Amazon SQS main queue, DLQ, and redrive policy
        └── vpc/                         # Multi-AZ VPC with public, DB, and cache subnets
```

---

## 6. Deployment & Verification Guide

### Prerequisites
- AWS CLI configured with valid deployment credentials.
- Terraform `>= 1.5.0` installed.
- Node.js `>= 18.x` for local validation.

### Step 1: Initialize and Plan Infrastructure
```bash
cd stage-5/terraform
cp terraform.tfvars.example terraform.tfvars

# Initialize Terraform modules and provider plugins
terraform init

# Validate configuration syntax
terraform validate

# Review execution plan
terraform plan -out=tfplan
```

### Step 2: Apply Infrastructure
```bash
terraform apply tfplan
```

### Step 3: Verify Deployment via cURL
1. **Check System Health:**
   ```bash
   curl -s http://<ALB_DNS_NAME>/health | jq .
   ```
   *Expected: Status `"UP"`, database `"Amazon RDS PostgreSQL"`, cache `"Amazon ElastiCache Redis"`, and queue `"Amazon SQS" (queueConfigured: true)`.*

2. **Check Real-Time SQS Queue Attributes:**
   ```bash
   curl -s http://<ALB_DNS_NAME>/api/queue/stats | jq .
   ```

3. **Place an Asynchronous Order:**
   ```bash
   curl -s -X POST http://<ALB_DNS_NAME>/api/orders \
     -H "Content-Type: application/json" \
     -d '{
       "customerName": "Vinod Kumar",
       "customerEmail": "vinod@shopsphere.io",
       "shippingAddress": "500 Cloud Parkway, Austin TX",
       "items": [{"productId": 1, "quantity": 1}]
     }' | jq .
   ```
   *Notice the instant HTTP 202 Accepted response:*
   ```json
   {
     "success": true,
     "orderId": 1,
     "status": "PENDING",
     "totalAmount": "199.99",
     "queuePublished": true,
     "sqsMessageId": "3453b0df-...",
     "checkoutLatencyMs": 14,
     "message": "Order accepted for asynchronous processing via Amazon SQS & AWS Lambda"
   }
   ```

4. **Verify Order Fulfillment via Lambda Worker:**
   ```bash
   # Poll status after 2-3 seconds
   curl -s http://<ALB_DNS_NAME>/api/orders/1/status | jq .
   ```
   *Expected: status changes from `PENDING` to `FULFILLED` with `processed_by_worker` populated.*

5. **Inspect CloudWatch Logs:**
   ```bash
   aws logs tail "/aws/lambda/shopsphere-stage5-order-processor" --follow
   ```

6. **Test Dead Letter Queue (DLQ) Failure Handling:**
   Submit an order with the failure simulation flag:
   ```bash
   curl -s -X POST http://<ALB_DNS_NAME>/api/orders \
     -H "Content-Type: application/json" \
     -d '{
       "customerName": "DLQ Test",
       "customerEmail": "dlq@test.io",
       "shippingAddress": "1 Error Way",
       "simulateFailure": true,
       "items": [{"productId": 1, "quantity": 1}]
     }'
   ```
   *The Lambda worker will reject the message 3 times, after which SQS will move it to `shopsphere-stage5-order-processing-dlq`.*

---

## 7. Teardown
When finished, clean up all provisioned resources to avoid AWS costs:
```bash
terraform destroy -auto-approve
```

---

## 8. Architectural Paradigms & Constraints Compliance

### What Stage 5 Implements
```
Synchronous application (EC2 ASG + ALB)
+
Asynchronous processing
+
Amazon SQS (Buffer)
+
AWS Lambda (Worker)
+
Dead Letter Queue (DLQ Redrive)
+
Least-Privilege IAM Roles
+
Amazon CloudWatch Logs
```

### Strict Architectural Boundaries (What Was NOT Introduced)
In accordance with incremental architectural principles:
- **NO Docker yet:** Containerization is strictly deferred to **Stage 8**.
- **NO Amazon EKS yet:** Kubernetes orchestration is strictly deferred to **Stage 9**.
- **NO GitOps / Argo CD yet:** Declarative continuous delivery is deferred to **Stage 10**.
- **NO Amazon CloudFront or AWS WAF yet:** Global Edge CDN and WAF rules belong to **Stage 6**.
- **NO unnecessary AWS services:** Direct SQS-to-Lambda event-driven pipeline without SNS, Step Functions, or NAT Gateways.
- **NO public database exposure:** Amazon RDS remains safely isolated in private database subnets with security group firewalls restricting inbound 5432.
- **NO hard-coded credentials:** All secrets are parameterized via Terraform variables and environment files.

---

## 9. Final Stage 5 High-Level Architecture

```
             Users
               │
               ▼
              ALB
               │
               ▼
        EC2 Auto Scaling
         /     │     \
        /      │      \
       ▼       ▼       ▼
      RDS    Redis    SQS
                       │
                       ▼
                     Lambda
                       │
                       ▼
              Background Processing
             (CloudWatch Logs & DLQ)
```

```
                       [ Full Event-Driven Flow ]

               Users
                 │
                 ▼
                ALB
                 │
                 ▼
          EC2 Auto Scaling Fleet
          ┌──────┴───────────────────────┐
          │ (Read/Write)                 │ (Cache-Aside)
          ▼                              ▼
     Amazon RDS                  Amazon ElastiCache
     PostgreSQL                        Redis
          │
          │ (Async ORDER_CREATED)
          ▼
     Amazon SQS (Main Queue)
          │
          ├──────────────────────────┐
          │ (Batch Event Source)     │ (Max Receives > 3)
          ▼                          ▼
     AWS Lambda Worker          Amazon SQS DLQ
     (Order Processing)         (Poison Pills)
          │
          ▼
     Amazon CloudWatch Logs
     (Structured Audit Trail)
```

