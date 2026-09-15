# ShopSphere Stage 8: Docker Containerization & Multi-Stage Image Security

## 1. Overview & Architectural Progression

Stage 8 transitions ShopSphere from traditional host-level virtual machine deployments to **standardized, immutable, and secure containerization** using **Docker**, **Multi-Stage Builds**, **Amazon Elastic Container Registry (ECR)**, and automated **Container Image Vulnerability Scanning**.

### The Problem in Previous Stages
In Stages 1 through 7, the application code, Node.js runtime, and dependencies were bootstrapped directly onto EC2 virtual machines via cloud-init (`user_data.sh.tpl`). This pattern introduced several operational challenges:
- **Environment Drift:** "Works on my machine" inconsistencies between local environments, staging, and production EC2 instances.
- **Slow Autoscaling Spinups:** New Auto Scaling instances took 3–5 minutes to install Node.js, clone the git repo, and run `npm install`.
- **Large Attack Surface:** EC2 host OS instances contained development utilities, compilers, package managers, and root daemons.
- **Image Bloat & Supply Chain Exposure:** OS-level packages (like curl, git, python) on virtual machines were rarely patched in lockstep with application updates.

### The Stage 8 Solution
1. **Multi-Stage Hardened Dockerfile:** Isolates dependency installation and build tools in a transient `builder` stage, copying only production runtime artifacts into a lean, non-root `node:18-alpine` runner container.
2. **Container Security Hardening:** Runs as a dedicated unprivileged user (`shopsphere` UID 10001), enforces POSIX signal handling with `dumb-init`, excludes sensitive files via `.dockerignore`, and adds native Docker `HEALTHCHECK` directives.
3. **Amazon Elastic Container Registry (ECR):** Terraform provisions a private, encrypted (`AES256`) container registry with **Scan on Push** enabled and automated lifecycle pruning.
4. **Local Multi-Container Orchestration (`docker-compose.yml`):** Developers can spin up the full platform (App + PostgreSQL 15 + Redis 7) with a single command (`docker compose up -d`).
5. **End-to-End Container CI/CD Pipeline (`stage-8/Jenkinsfile`):** Enforces Dockerfile linting (`Hadolint`), container image vulnerability scanning (`Trivy Image`), automated ECR publishing, and zero-downtime rolling container updates across the ASG fleet.

---

## 2. Architecture Diagram

```
                                  STAGE 8 DOCKER ARCHITECTURE
                                  
       Developers                       GitHub                          Jenkins CI/CD
     ┌─────────────┐             ┌──────────────────┐             ┌──────────────────────┐
     │ Local Dev   │ ──git push──►  Repository      │ ──webhook──►│ Hadolint + Trivy     │
     │ compose.yml │             └──────────────────┘             │ Multi-Stage Build    │
     └─────────────┘                                              └──────────┬───────────┘
                                                                             │ docker push
                                                                             ▼
                                                                  ┌──────────────────────┐
                                                                  │   Amazon ECR         │
                                                                  │   Container Registry │
                                                                  │   (Scan on Push)     │
                                                                  └──────────┬───────────┘
                                                                             │
                                                                             │ docker pull
                                                                             ▼
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Global Edge Tier (AWS CloudFront CDN + AWS WAFv2)                                                     │
│   • https://d123456abcdef.cloudfront.net                                                             │
│   • OWASP Top 10 Perimeter Filtering (SQLi, XSS, Rate Limiting)                                      │
└───────────────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                                    │ HTTPS (X-Custom-Header Origin Secret)
                                                    ▼
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Ingress Tier (Application Load Balancer)                                                              │
│   • Header Lockdown: Direct IP access without CloudFront secret returns HTTP 403 Forbidden            │
└───────────────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                                    │ Forward to Target Group (Port 80)
                                                    ▼
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Multi-AZ Auto Scaling Group (Docker Host Fleet)                                                       │
│                                                                                                       │
│   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────────────┐   │
│   │ EC2 Node 1 (us-east-1a)                       │   │ EC2 Node 2 (us-east-1b)                   │   │
│   │   • Nginx Reverse Proxy (:80)                 │   │   • Nginx Reverse Proxy (:80)             │   │
│   │   • Docker CE Engine                          │   │   • Docker CE Engine                      │   │
│   │   ┌─────────────────────────────────────────┐ │   │   ┌─────────────────────────────────────┐ │   │
│   │   │ shopsphere-app Container (:8080)        │ │   │   │ shopsphere-app Container (:8080)    │ │   │
│   │   │ • Multi-Stage Alpine (Non-root UID 10001)│ │   │   │ • Multi-Stage Alpine (Non-root)     │ │   │
│   │   │ • /health probe & /api/container-info   │ │   │   │ • /health probe & /api/container-info│ │   │
│   │   └────────────────────┬────────────────────┘ │   │   └──────────────────┬──────────────────┘ │   │
│   └────────────────────────┼──────────────────────┘   └──────────────────────┼────────────────────┘   │
└────────────────────────────┼─────────────────────────────────────────────────┼────────────────────────┘
                             │                                                 │
                             ▼                                                 ▼
┌─────────────────────────────────────────┐       ┌─────────────────────────────────────────────────────┐
│ Decoupled Managed Persistence           │       │ Decoupled Asynchronous Processing                   │
│   • Amazon RDS PostgreSQL (Port 5432)   │       │   • Amazon SQS FIFO Queue (Orders)                  │
│   • Amazon ElastiCache Redis (Port 6379)│       │   • AWS Lambda Serverless Worker (Consumer)         │
└─────────────────────────────────────────┘       └─────────────────────────────────────────────────────┘
```

---

## 3. Multi-Stage Dockerfile Security Blueprint

The Stage 8 `Dockerfile` (`stage-8/app/Dockerfile`) utilizes Docker multi-stage builds to produce a hardened production runtime:

```dockerfile
# ------------------------------------------------------------------------------
# Stage 1: Build & Dependencies
# ------------------------------------------------------------------------------
FROM node:18-alpine AS builder

WORKDIR /app
RUN apk update && apk upgrade --no-cache
COPY package.json ./
RUN npm install --omit=dev --cache /tmp/.npm && rm -rf /tmp/.npm
COPY server.js ./
COPY db/ ./db/
COPY public/ ./public/

# ------------------------------------------------------------------------------
# Stage 2: Hardened Runtime Container
# ------------------------------------------------------------------------------
FROM node:18-alpine AS runner

RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache wget curl dumb-init && \
    rm -rf /var/cache/apk/*

# Dedicated unprivileged user (Non-root security)
RUN addgroup -g 10001 -S shopsphere && \
    adduser -u 10001 -S shopsphere -G shopsphere -h /app -s /bin/sh

WORKDIR /app
ENV NODE_ENV=production PORT=8080 STAGE_NAME=stage-8

COPY --from=builder --chown=shopsphere:shopsphere /app/node_modules ./node_modules
COPY --from=builder --chown=shopsphere:shopsphere /app/package.json ./package.json
COPY --from=builder --chown=shopsphere:shopsphere /app/server.js ./server.js
COPY --from=builder --chown=shopsphere:shopsphere /app/db ./db
COPY --from=builder --chown=shopsphere:shopsphere /app/public ./public

USER shopsphere
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
```

### Security Guardrails Implemented
| Guardrail | Implementation | Benefit |
| :--- | :--- | :--- |
| **Multi-Stage Separation** | `AS builder` & `AS runner` | Compilers, npm caches, and build tools are discarded from the runtime image. |
| **Non-Root Execution** | `USER shopsphere (UID 10001)` | Prevents container breakout and unauthorized access to host resources. |
| **POSIX Signal Forwarding** | `dumb-init` ENTRYPOINT | Ensures graceful shutdown signals (`SIGTERM`, `SIGINT`) are handled properly without zombie processes. |
| **Container Self-Healing** | `HEALTHCHECK` directive | Enables Docker and container orchestrators to detect and replace degraded containers. |
| **Context Hygiene** | `.dockerignore` | Prevents `.env`, secrets, `.git`, test scripts, and node_modules from leaking into image layers. |

---

## 4. Local Multi-Container Development (Docker Compose)

Developers can run the complete platform locally using Docker Compose without needing AWS resources:

```bash
cd stage-8/app

# Start App, PostgreSQL, and Redis containers in the background
docker compose up -d --build

# View real-time container logs
docker compose logs -f app

# Inspect container status and healthchecks
docker compose ps

# Test the local application health probe
curl -s http://localhost:8080/health | jq .

# Test the container diagnostics endpoint
curl -s http://localhost:8080/api/container-info | jq .

# Stop and remove all containers and volumes
docker compose down -v
```

---

## 5. Enterprise Container CI/CD Pipeline (`stage-8/Jenkinsfile`)

```text
               GitHub
                 │
                 ▼
              Jenkins
                 │
         ┌───────┴───────┐
         ▼               ▼
      Checkout   Security Analysis (Gitleaks, Semgrep, Trivy SCA)
         │               │
         └───────┬───────┘
                 ▼
            Unit Tests (node --test)
                 ▼
      Dockerfile Linting (Hadolint)
                 ▼
          Docker Build (Multi-Stage)
                 ▼
     Container Image Scan (Trivy Image)
                 ▼
    Infrastructure Provisioning (Terraform + ECR)
                 ▼
         Amazon ECR Push (Tag & Release)
                 ▼
     ASG Container Rollout (Instance Refresh)
                 ▼
 Verify App Health, Container, ALB & CloudFront (CNF)
                 ▼
               DAST (OWASP ZAP Dynamic Scan)
                 ▼
           Security Gate (Threshold Enforcement)
```

### Pipeline Execution Modes
- **`ACTION = 'apply'`** *(Default)*: Full end-to-end run: Lints Dockerfile, compiles multi-stage container, scans image with Trivy, provisions AWS infrastructure (including ECR), pushes image to ECR, triggers ASG instance refresh, verifies 3-tier health, and runs DAST.
- **`ACTION = 'container-update'`**: Rapid container deployment: Runs tests, builds image, scans image, pushes to ECR, and refreshes the ASG container fleet without running Terraform apply.
- **`ACTION = 'plan'`**: Dry-run Terraform execution plan.
- **`ACTION = 'destroy'`**: Tears down the Stage 8 AWS test environment.

---

## 6. Terraform Verification & Deployment Runbook

```bash
cd stage-8/terraform

# 1. Initialize Terraform
terraform init

# 2. Validate configuration syntax
terraform validate

# 3. Preview execution plan
terraform plan

# 4. Provision full infrastructure (VPC, ALB, ASG, ECR, CloudFront, WAF, RDS, Redis, SQS, Lambda)
terraform apply -auto-approve

# 5. Retrieve deployment endpoints
export CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)
export ALB_DNS=$(terraform output -raw alb_dns_name)
export ECR_URL=$(terraform output -raw ecr_repository_url)

echo "CloudFront URL: https://${CF_DOMAIN}"
echo "ALB Origin    : http://${ALB_DNS}"
echo "ECR Registry  : ${ECR_URL}"
```

### Post-Deployment Verification
```bash
# 1. Verify Container Runtime Diagnostics
curl -s "https://${CF_DOMAIN}/api/container-info" | jq .

# 2. Verify Application Health
curl -s "https://${CF_DOMAIN}/health" | jq .

# 3. Verify ALB Origin Lockdown (Direct access MUST return HTTP 403)
curl -i "http://${ALB_DNS}/health"

# 4. Verify AWS WAF Perimeter Inspection (SQLi probe MUST return HTTP 403)
curl -i "https://${CF_DOMAIN}/api/products?id=1%20OR%201=1"
```

---

## 7. Limitations & Technical Debt

1. **Static Host-Bound Containers:** In Stage 8, containers run on standalone EC2 ASG hosts managed by user data scripts rather than a dedicated container orchestrator.
2. **Container Scheduling & Service Discovery:** Load balancing relies on host-level ALB target groups rather than native container-level ingress routing and service discovery.
3. **Secrets Management:** Environment variables are injected on boot rather than securely rotated via native Kubernetes secrets / external secret operators.

---

## 8. Next Step: Stage 9 — Kubernetes (EKS)

With multi-stage, security-scanned container images published to Amazon ECR, the application is ready for production container orchestration with **Amazon Elastic Kubernetes Service (EKS)**:

```
Stage 9 → EKS (Kubernetes Container Orchestration, Helm Charts, HPA, Ingress Controller & Cluster Autoscaler)
```
