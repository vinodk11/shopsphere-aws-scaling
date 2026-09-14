# ShopSphere: Cloud Architecture Evolution

## Stage 6: Amazon CloudFront + AWS WAF (Global Edge CDN, Web Application Firewall & Origin Lockdown)

Welcome to **Stage 6** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we advance ShopSphere to the global perimeter by introducing **Amazon CloudFront** as an Anycast Content Delivery Network (CDN) and **AWS WAFv2** as a Layer 7 Web Application Firewall. By integrating edge caching, managed threat mitigation, rate limiting, and an **ALB Origin Header Lockdown (`X-Origin-Verify`)**, ShopSphere achieves global sub-50ms static latency, comprehensive OWASP Top 10 perimeter defense, and bulletproof origin protection.

---

## 1. Stage 6 Objective & Evolution Path

```
Stage 1  → Monolith + EC2
Stage 2  → RDS PostgreSQL (Database Decoupling)
Stage 3  → ALB + Auto Scaling Group (Horizontal Scaling & High Availability)
Stage 4  → Redis / ElastiCache (In-Memory Caching & Session Management)
Stage 5  → SQS + Lambda (Decoupled Asynchronous Order Processing)
[ CURRENT ] Stage 6  → CloudFront + WAF (Global Edge CDN & Web Security)
Stage 7  → DevSecOps (SAST, DAST, SCA, Secrets Detection, Container Scanning, Pipeline Security)
Stage 8  → Docker (Containerization & Multi-Stage Builds)
Stage 9  → EKS (Kubernetes Container Orchestration & Microservices)
Stage 10 → GitOps / Argo CD (Continuous Delivery & Full Observability)
```

### What Problem Are We Solving from Stage 5?
In Stage 5, ShopSphere handled compute elasticity with Auto Scaling and order decoupling via SQS + Lambda. However, the architecture suffered from several perimeter limitations:
1. **Global Latency & Bandwidth Waste:** Every client across the world had to establish a full TLS handshake and fetch static assets (CSS, JS, product images, icons) all the way from the regional Application Load Balancer in `us-east-1`.
2. **Layer 7 Vulnerability Exposure:** The ALB and EC2 instances were directly exposed to HTTP floods, malicious scrapers, SQL injections (SQLi), Cross-Site Scripting (XSS), and bad bot traffic.
3. **Origin Exposure & WAF Bypass Risk:** In naive CDN setups, attackers can scan for or discover the raw ALB DNS name (`shopsphere-alb-xxxx.elb.amazonaws.com`) and target it directly, completely bypassing CloudFront and any perimeter firewall.
4. **Origin Compute Exhaustion:** EC2 instances had to serve static files alongside dynamic business logic, consuming CPU cycles and socket descriptors that should be reserved for order transactions.

### How Stage 6 Solves This:
- **Global Edge Caching (CloudFront):** Static assets are cached across 450+ Points of Presence (POPs) globally, slashing TTFB (Time To First Byte) from ~350ms to `< 40ms` and reducing origin network egress by up to 80%.
- **Perimeter Threat Defense (AWS WAFv2):** Inspects incoming HTTP/S requests at the edge before they touch the AWS internal network. Requests matching OWASP attack signatures, known bad inputs, or blacklisted IPs are blocked with HTTP 403 at edge POPs.
- **Layer 7 Rate Limiting:** Enforces a strict threshold of 500 requests per 5 minutes per IP address to throttle credential stuffing and brute-force attacks.
- **ALB Origin Header Lockdown:** The Application Load Balancer is configured with a custom header verification rule (`X-Origin-Verify`). CloudFront injects a cryptographically random secret header into all origin requests; direct access to the ALB without this header is rejected with HTTP 403 Forbidden.

---

## 2. Stage 6 Architecture Diagram

```
+=======================================================================================================================================+
|                                                          Global Edge (Anycast Network)                                                |
|                                                                                                                                       |
|                                                     Internet Users (Worldwide)                                                       |
|                                                                 │                                                                     |
|                                                                 ▼                                                                     |
|                                                  +──────────────────────────────+                                                     |
|                                                  │          AWS WAFv2           │  (Scope: CLOUDFRONT / us-east-1)                        |
|                                                  │  - AWSManagedRulesCommon     │  -> Priority 10 (OWASP Top 10)                           |
|                                                  │  - AWSManagedRulesKnownBad   │  -> Priority 20 (Exploits/RCE)                          |
|                                                  │  - AWSManagedRulesIpRep      │  -> Priority 30 (Amazon Threat Intel)                   |
|                                                  │  - RateLimitPerIP            │  -> Priority 40 (500 req/5m per IP)                     |
|                                                  +──────────────────────────────+                                                     |
|                                                                 │                                                                     |
|                                                                 ▼                                                                     |
|                                                  +──────────────────────────────+                                                     |
|                                                  │   Amazon CloudFront CDN      │                                                     |
|                                                  │  - Global Edge POPs (450+)   │                                                     |
|                                                  │  - HTTPS / TLS Termination   │                                                     |
|                                                  │  - Injects X-Origin-Verify   │                                                     |
|                                                  +──────────────────────────────+                                                     |
|                                                     │                        │                                                        |
|                                    Static Asset HIT │                        │ Dynamic API / Cache MISS                               |
|                                    (Styles, Images) │                        │ (Forward with X-Origin-Verify)                         |
|                                                     ▼                        ▼                                                        |
+=======================================================================================================================================+
                                     Cached at Edge                AWS Cloud (Region: us-east-1)                                        
                                  (Sub-40ms Delivery)                          │                                                        
+==============================================================================│========================================================+
|                                                              Dedicated VPC   ▼                                                        |
|                                              +─────────────────────────────────────────────────────────+                              |
|                                              │ Application Load Balancer (ALB Tier)                    │                              |
|                                              │ Security Group: Port 80 / 443                            │                              |
|                                              │ Origin Header Lockdown:                                 │                              |
|                                              │   IF HTTP Header X-Origin-Verify == <SecretToken>        │                              |
|                                              │     -> FORWARD to EC2 Target Group                       │                              |
|                                              │   ELSE                                                  │                              |
|                                              │     -> RETURN HTTP 403 Forbidden                         │                              |
|                                              +─────────────────────────────────────────────────────────+                              |
|                                                            │                               │                                          |
|                                                            │ HTTP                          │ HTTP                                     |
|                                                            ▼                               ▼                                          |
|                                              +───────────────────────────+   +───────────────────────────+                            |
|                                              │ Public Subnet 1 (AZ-A)    │   │ Public Subnet 2 (AZ-B)    │                            |
|                                              │ EC2 Instance (ASG Fleet)  │   │ EC2 Instance (ASG Fleet)  │                            |
|                                              │ - Node.js App (Port 8080) │   │ - Node.js App (Port 8080) │                            |
|                                              │ - CloudFront Header Aware │   │ - CloudFront Header Aware │                            |
|                                              +───────────────────────────+   +───────────────────────────+                            |
|                                                    │           │                       │           │                                  |
|                                           TCP 6379 │  TCP 5432 │              TCP 5432 │  TCP 6379 │                                  |
|                                                    ▼           ▼                       ▼           ▼                                  |
|                                              +───────────+ +───────────+       +───────────+ +───────────+                            |
|                                              │ElastiCache│ │Amazon RDS │       │Amazon RDS │ │ElastiCache│                            |
|                                              │Redis Cache│ │PostgreSQL │       │PostgreSQL │ │Redis Cache│                            |
|                                              +───────────+ +───────────+       +───────────+ +───────────+                            |
|                                                                │                   │                                                  |
|                                                                +─────────┬─────────+                                                  |
|                                                                          │                                                            |
|                                                                          ▼ HTTPS (Publish Event)                                      |
|                                                          +───────────────────────────────+                                            |
|                                                          │ Amazon SQS Order Event Queue  │                                            |
|                                                          │ - SSE-SQS Encrypted           │                                            |
|                                                          │ - Dead Letter Queue Attached  │                                            |
|                                                          +───────────────────────────────+                                            |
|                                                                          │                                                            |
|                                                                          ▼ Batch Polling                                              |
|                                                          +───────────────────────────────+                                            |
|                                                          │ AWS Lambda Serverless Worker  │                                            |
|                                                          │ - Runtime: Node.js 20.x       │                                            |
|                                                          │ - Updates RDS to FULFILLED    │                                            |
|                                                          +───────────────────────────────+                                            |
+=======================================================================================================================================+
```

---

## 3. CloudFront Edge Caching & Routing Behavior

CloudFront is configured with path-based cache behaviors optimized for e-commerce performance:

| Path Pattern | Target Origin | Caching Policy | Allowed Methods | Query / Cookies | Use Case |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Default (*)` | ALB | **TTL: 86,400s (1 Day)**<br>Min: 0s, Max: 31,536,000s | `GET, HEAD, OPTIONS` | Cookies: `none`<br>Query: `false` | Static storefront assets (CSS, JS, images, fonts). Cached globally at edge POPs. |
| `/api/*` | ALB | **TTL: 0s (Pass-through)**<br>Cache-Control: `no-cache` | `GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE` | Cookies: `all`<br>Query: `all` | Dynamic backend APIs, real-time checkout, cart operations, SQS submissions. |
| `/health` | ALB | **TTL: 0s (Pass-through)**<br>No edge caching | `GET, HEAD` | Cookies: `none`<br>Query: `false` | Real-time origin health checks and latency probes. |

### Viewer Location Headers Forwarding
CloudFront is configured to forward viewer geolocation headers to the origin without caching:
- `CloudFront-Viewer-Country`: ISO 3166-1 alpha-2 country code (e.g. `US`, `GB`, `IN`).
- `CloudFront-Viewer-Country-Name`: Viewer country name.
- `CloudFront-Is-Mobile-Viewer`, `CloudFront-Is-Desktop-Viewer`, `CloudFront-Is-Tablet-Viewer`: Device categorization flags.
- `X-Amz-Cf-Id`: Unique CloudFront Ray/Request ID for end-to-end tracing.

---

## 4. AWS WAFv2 Architecture & Threat Mitigation Rules

AWS WAF Web ACL is deployed with `scope = "CLOUDFRONT"` in AWS region `us-east-1` (the required region for CloudFront associations). It evaluates requests against four prioritized rule sets:

```
Incoming Request at CloudFront Edge
               │
               ▼
[ Priority 10: AWSManagedRulesCommonRuleSet ]
  ├─ OWASP Top 10 vulnerabilities
  ├─ Cross-Site Scripting (XSS)
  ├─ Generic Local/Remote File Inclusion (LFI/RFI)
  ├─ Size restrictions and HTTP protocol violations
  └─ Action: BLOCK (HTTP 403)
               │ (Pass)
               ▼
[ Priority 20: AWSManagedRulesKnownBadInputsRuleSet ]
  ├─ Known invalid payloads & exploit patterns (e.g., Log4Shell, command injection)
  ├─ Malformed requests & probe strings
  └─ Action: BLOCK (HTTP 403)
               │ (Pass)
               ▼
[ Priority 30: AWSManagedRulesAmazonIpReputationList ]
  ├─ AWS Threat Intelligence real-time IP reputation
  ├─ Known scanner IPs, botnets, and Tor exit nodes
  └─ Action: BLOCK (HTTP 403)
               │ (Pass)
               ▼
[ Priority 40: RateLimitPerIP ]
  ├─ Evaluates request count per individual client IP
  ├─ Threshold: 500 requests per 5-minute rolling window
  └─ Action: BLOCK (HTTP 403)
               │ (Pass)
               ▼
[ Default Action: ALLOW ] ──► Forwarded to CloudFront Cache / Origin ALB
```

---

## 5. Origin Defense-in-Depth: ALB Header Lockdown

### The Attack Vector:
When an Application Load Balancer has an internet-facing DNS name, attackers can discover it (via DNS enumeration, Shodan, or HTTP referer leaks) and send requests directly to the ALB, bypassing CloudFront and AWS WAF entirely.

### The Stage 6 Solution:
1. Terraform generates a cryptographically secure random token:
   ```hcl
   resource "random_password" "origin_secret" {
     length  = 32
     special = false
   }
   ```
2. CloudFront is configured to inject this secret as a custom origin header:
   ```hcl
   custom_header {
     name  = "X-Origin-Verify"
     value = random_password.origin_secret.result
   }
   ```
3. The ALB HTTP listener default action is configured to **Block (HTTP 403 Forbidden)**:
   ```hcl
   default_action {
     type = "fixed-response"
     fixed_response {
       content_type = "text/plain"
       message_body = "Access Denied: Direct origin access is forbidden. Please access via CloudFront."
       status_code  = "403"
     }
   }
   ```
4. A dedicated ALB listener rule permits traffic **only** if `X-Origin-Verify` matches the secret token:
   ```hcl
   condition {
     http_header {
       http_header_name = "X-Origin-Verify"
       values           = [var.origin_verify_secret]
     }
   }
   ```
Result: Any direct traffic to the ALB returns `403 Forbidden`. Only requests routed through CloudFront (and inspected by AWS WAF) reach the EC2 instances.

---

## 6. Directory Structure & Modular Infrastructure

```
stage-6/
├── Jenkinsfile                          # Automated CI/CD pipeline (Init, Validate, Plan, Apply, Verify)
├── README.md                            # Comprehensive architectural documentation (this file)
├── app/                                 # Storefront application
│   ├── db/
│   │   └── schema.sql                   # Database schema & initial product catalog
│   ├── package.json                     # Node.js dependencies & scripts (v6.0.0)
│   ├── public/
│   │   ├── index.html                   # Storefront UI with 6-tier Edge & Pipeline visualizer
│   │   └── styles.css                   # Responsive styles with edge diagnostic badges
│   └── server.js                        # Express server with CloudFront header parsing & /api/edge-info
└── terraform/                           # Infrastructure as Code
    ├── data.tf                          # AMI and Availability Zone lookups
    ├── main.tf                          # Root module wiring all 11 infrastructure tiers
    ├── outputs.tf                       # CloudFront domain, ALB DNS, and resource outputs
    ├── provider.tf                      # Default provider + aliased aws.us_east_1 for WAF
    ├── terraform.tfvars.example         # Example configuration variables
    ├── variables.tf                     # Input variable declarations
    ├── versions.tf                      # Terraform & provider version constraints
    ├── modules/
    │   ├── alb/                         # ALB module with enable_header_lockdown support
    │   ├── asg/                         # Auto Scaling Group & EC2 Launch Template
    │   ├── cloudfront/                  # CloudFront distribution, cache behaviors & origin headers
    │   ├── elasticache/                 # Redis cluster in private database subnets
    │   ├── iam/                         # Least-privilege IAM roles (EC2 & Lambda)
    │   ├── lambda/                      # Order fulfillment worker function
    │   ├── rds/                         # Amazon RDS PostgreSQL 15 instance
    │   ├── security-group/              # Multi-tier network security groups
    │   ├── sqs/                         # Order ingestion SQS queue + Dead Letter Queue
    │   ├── vpc/                         # Multi-AZ VPC with public & private subnets
    │   └── waf/                         # AWS WAFv2 Web ACL (scope: CLOUDFRONT in us-east-1)
    └── scripts/
        ├── lambda_worker.js             # Serverless fulfillment worker code
        └── user_data.sh.tpl             # EC2 bootstrap script installing Node 20 & app
```

---

## 7. Terraform Verification & Deployment Runbook

### Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured with administrator or deployment credentials
- AWS Region: `us-east-1` (or another region, with `aws.us_east_1` provider handling WAF)

### Step 1: Initialize & Validate Terraform
```bash
cd stage-6/terraform
terraform init
terraform validate
```
Expected output:
```
Success! The configuration is valid.
```

### Step 2: Review Execution Plan
```bash
terraform plan -out=tfplan
```
Review the planned additions across all 11 modules:
- CloudFront distribution (`aws_cloudfront_distribution.main`)
- WAFv2 Web ACL (`aws_wafv2_web_acl.cloudfront_waf`)
- ALB header verification listener rules
- Multi-AZ VPC, ALB, ASG, RDS, ElastiCache, SQS, and Lambda.

### Step 3: Apply Infrastructure
```bash
terraform apply tfplan
```
*Note: CloudFront distribution provisioning across global edge locations typically takes 3–5 minutes.*

### Step 4: Verification & Testing
Once deployment completes, Terraform outputs the CloudFront domain name and ALB DNS:

```bash
# Capture endpoints from Terraform outputs
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)
ALB_DNS=$(terraform output -raw alb_dns_name)
```

#### Test 1: Verify Storefront & Edge Health Check
```bash
curl -i "https://${CF_DOMAIN}/health"
```
Verify the response includes:
- HTTP status `200 OK`
- `"stage": "Stage 6: CloudFront + AWS WAF + ALB + ASG + Redis + Amazon SQS + AWS Lambda + Amazon RDS"`
- CloudFront headers: `Via: 2.0 xxxxxxxxx.cloudfront.net (CloudFront)` and `X-Served-By: ip-10-0-x-x`

#### Test 2: Verify ALB Direct Access Lockdown (Expected: 403 Forbidden)
```bash
curl -i "http://${ALB_DNS}/health"
```
Expected response:
```http
HTTP/1.1 403 Forbidden
Content-Type: text/plain
Content-Length: 79

Access Denied: Direct origin access is forbidden. Please access via CloudFront.
```
*This confirms that attackers cannot bypass CloudFront or AWS WAF by hitting the ALB directly.*

#### Test 3: Verify AWS WAF L7 Threat Blocking (Expected: 403 Forbidden)
Simulate a SQL Injection payload in the query string:
```bash
curl -i "https://${CF_DOMAIN}/api/products?id=1%20OR%201=1"
```
Expected response from AWS WAF:
```http
HTTP/2 403
server: CloudFront
x-amz-cf-pop: IAD89-C1
...
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML><HEAD><TITLE>403 Forbidden</TITLE></HEAD>
<BODY><H1>403 Forbidden</H1>Request blocked by Web Application Firewall.</BODY></HTML>
```

#### Test 4: Verify Edge Caching for Static Assets
```bash
# First request: Cache MISS (forwarded to origin)
curl -s -I "https://${CF_DOMAIN}/styles.css" | grep -iE "(x-cache|age)"
# Expected: X-Cache: Miss from cloudfront, Age: 0

# Second request: Cache HIT (served from local edge POP)
curl -s -I "https://${CF_DOMAIN}/styles.css" | grep -iE "(x-cache|age)"
# Expected: X-Cache: Hit from cloudfront, Age: > 0
```

#### Test 5: Verify Edge Diagnostics API
```bash
curl -s "https://${CF_DOMAIN}/api/edge-info" | jq .
```
Returns:
```json
{
  "success": true,
  "edgeDelivery": {
    "isViaCloudFront": true,
    "cloudFrontRayId": "91b8f10b...",
    "viewer": {
      "countryCode": "US",
      "deviceType": "Desktop"
    },
    "originProtection": {
      "headerLockdown": "X-Origin-Verify",
      "verificationStatus": "VERIFIED_MATCH"
    }
  },
  "wafProtection": {
    "status": "ACTIVE",
    "scope": "CLOUDFRONT (Global us-east-1)",
    "managedRuleGroups": [
      { "name": "AWSManagedRulesCommonRuleSet", "action": "BLOCK" },
      { "name": "AWSManagedRulesKnownBadInputsRuleSet", "action": "BLOCK" },
      { "name": "AWSManagedRulesAmazonIpReputationList", "action": "BLOCK" },
      { "name": "RateLimitPerIP (500 req/5m)", "action": "BLOCK" }
    ]
  }
}
```

---

## 8. Limitations & Technical Debt

While Stage 6 provides enterprise-grade perimeter security and global edge acceleration, the following areas represent intentional scope boundaries for future stages:
1. **Custom Domain & ACM Certificate:** Uses the default `*.cloudfront.net` SSL/TLS certificate. Production environments would attach a custom domain (e.g., `shopsphere.example.com`) via Route 53 with an AWS Certificate Manager (ACM) public certificate in `us-east-1`.
2. **Containerization:** The application runs on EC2 instances provisioned with a Bash user data bootstrap. Moving to Docker containers (Stage 8) and Kubernetes (Stage 9) will eliminate configuration drift and standardize deployments.
3. **Security Pipeline Gates:** Currently, security inspection occurs at runtime via WAF. Pre-commit, build-time, and pipeline-level security scanning (SAST, DAST, SCA, secrets detection) are addressed in **Stage 7: DevSecOps**.

---

## 9. Next Step: Stage 7 — DevSecOps

In accordance with the 10-stage project roadmap, the next stage is:

```
Stage 7 → DevSecOps (SAST, DAST, SCA, Secrets Detection, Pipeline Security)
```

> [!IMPORTANT]
> **Stage 7 will NOT be skipped.** In Stage 7, we will embed comprehensive security automation into the CI/CD pipeline:
> - **SAST (Static Application Security Testing):** Semgrep / SonarQube rules for Node.js.
> - **SCA (Software Composition Analysis):** Trivy / npm audit for supply chain vulnerability scanning.
> - **Secrets Detection:** Gitleaks / Trufflehog scanning to prevent credential leakage.
> - **IaC Security:** tfsec / Checkov policy scanning on Terraform configurations.
> - **DAST (Dynamic Application Security Testing):** OWASP ZAP automated dynamic vulnerability scanning against the live application.
