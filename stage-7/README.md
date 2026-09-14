# ShopSphere: Cloud Architecture Evolution

## Stage 7: DevSecOps (Shift-Left Pipeline Security, Automated Quality Gates & Hardened Architecture)

Welcome to **Stage 7** of the **ShopSphere** AWS Architecture Evolution series.

In this stage, we transition from purely perimeter and runtime defense to an end-to-end **DevSecOps** methodology. By embedding automated security quality gates directly into the CI/CD pipeline, ShopSphere enforces the principle of **"Shift-Left Security"**: catching secrets leaks, application vulnerabilities, vulnerable supply chain packages, and infrastructure misconfigurations before code ever reaches production.

---

## 1. Stage 7 Objective & Evolution Path

```
Stage 1  → Monolith + EC2
Stage 2  → RDS PostgreSQL (Database Decoupling)
Stage 3  → ALB + Auto Scaling Group (Horizontal Scaling & High Availability)
Stage 4  → Redis / ElastiCache (In-Memory Caching & Session Management)
Stage 5  → SQS + Lambda (Decoupled Asynchronous Order Processing)
Stage 6  → CloudFront + WAF (Global Edge CDN & Web Security)
[ CURRENT ] Stage 7  → DevSecOps (SAST, DAST, SCA, Secrets Detection, IaC Compliance & Quality Gates)
Stage 8  → Docker (Containerization & Multi-Stage Builds)
Stage 9  → EKS (Kubernetes Container Orchestration & Microservices)
Stage 10 → GitOps / Argo CD (Continuous Delivery & Full Observability)
```

### Why DevSecOps Before Containerization (Stage 8) & Kubernetes (Stage 9)?
A common anti-pattern in cloud architecture is rushing into containerization (Docker) and orchestration (Kubernetes) without a security baseline. If code contains hardcoded secrets or unpatched CVEs, wrapping it inside a Docker container merely containerizes the vulnerability.

Stage 7 establishes an unyielding security baseline across 5 distinct domains:
1. **Secrets Detection (Gitleaks):** Prevents credential leakage (AWS access keys, database passwords, private keys) before commits are merged or pushed.
2. **SAST - Static Application Security Testing (Semgrep):** Analyzes Node.js source code for injection flaws, XSS, insecure deserialization, and dangerous sinks.
3. **SCA - Software Composition Analysis (Trivy):** Audits third-party npm packages against national vulnerability databases (NVD) to block supply chain attacks.
4. **IaC Security Compliance (Checkov):** Audits Terraform infrastructure code against the **CIS AWS Foundations Benchmark** and security best practices.
5. **DAST - Dynamic Application Security Testing (OWASP ZAP):** Performs automated dynamic penetration testing against live CloudFront and application endpoints, verifying runtime resilience and security headers.

---

## 2. DevSecOps Architecture & Pipeline Flow

```
+===================================================================================================================+
|                                      ShopSphere DevSecOps Continuous Delivery Pipeline                            |
|                                                                                                                   |
|   Developer Commit / Pull Request                                                                                 |
|               │                                                                                                   |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Gate 1: Secrets Scanning          │ ──► [ Gitleaks v8 ]                                                       |
|   │ - AWS Access Keys & Secrets       │     Scans git history & staging for high-entropy tokens                   |
|   │ - Database credentials & JWTs     │     THRESHOLD: Zero secrets permitted (Break on detection)                |
|   +───────────────────────────────────+                                                                           |
|               │ (Pass)                                                                                            |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Gate 2: SAST Code Analysis        │ ──► [ Semgrep CE ]                                                        |
|   │ - OWASP Top 10 rule enforcement   │     Static AST inspection of Node.js app & Lambda code                    |
|   │ - SQL Injection & XSS detection   │     THRESHOLD: Zero HIGH/CRITICAL code flaws                              |
|   +───────────────────────────────────+                                                                           |
|               │ (Pass)                                                                                            |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Gate 3: SCA Supply Chain          │ ──► [ Trivy / npm audit ]                                                 |
|   │ - Dependency manifest audit       │     Scans package.json against NVD/CVE feeds                              |
|   │ - Third-party library CVEs        │     THRESHOLD: Zero CRITICAL unpatched CVEs                               |
|   +───────────────────────────────────+                                                                           |
|               │ (Pass)                                                                                            |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Gate 4: IaC Security Compliance   │ ──► [ Checkov / tfsec ]                                                   |
|   │ - CIS AWS Foundations Benchmark   │     Audits 11 Terraform modules (VPC, SG, IAM, RDS, CloudFront, WAF)     |
|   │ - Least-privilege IAM policies    │     THRESHOLD: Pass all security & encryption baselines                   |
|   +───────────────────────────────────+                                                                           |
|               │ (Pass)                                                                                            |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Manual Security Approval Gate     │ ──► Jenkins pipeline reviews scan metrics before infrastructure rollout   |
|   +───────────────────────────────────+                                                                           |
|               │ (Approved)                                                                                        |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Terraform Plan & Apply            │ ──► Deploys hardened infrastructure across AWS                            |
|   +───────────────────────────────────+                                                                           |
|               │ (Deployed)                                                                                        |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Gate 5: DAST Dynamic Testing      │ ──► [ OWASP ZAP Baseline ]                                                |
|   │ - Probes live CloudFront endpoint │     Evaluates HTTP security headers (CSP, HSTS, X-Frame-Options)          |
|   │ - Tests SQLi & XSS resistance     │     Verifies ALB lockdown & WAF blocking efficacy                         |
|   +───────────────────────────────────+                                                                           |
|               │                                                                                                   |
|               ▼                                                                                                   |
|   +───────────────────────────────────+                                                                           |
|   │ Security Reports & Quality Gate   │ ──► Archives SARIF, JSON, and HTML reports in Jenkins artifacts           |
|   +───────────────────────────────────+                                                                           |
+===================================================================================================================+
```

---

## 3. The 5 DevSecOps Security Pillars in Detail

| Gate | Focus Area | Primary Tool | Target Path | Configuration File | Fail Criteria |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Gate 1** | **Secrets Detection** | `Gitleaks` | `stage-7/` | `security/secrets/.gitleaks.toml` | Any unencrypted AWS key, DB secret, or private key. |
| **Gate 2** | **SAST** | `Semgrep` | `stage-7/app/`, `stage-7/lambda/` | `security/sast/semgrep.yml` | Any HIGH/CRITICAL vulnerability (SQLi, XSS, Path Traversal). |
| **Gate 3** | **SCA (Supply Chain)** | `Trivy` | `stage-7/app/package.json` | `security/sca/trivy.yaml` | Any HIGH/CRITICAL unpatched package CVE. |
| **Gate 4** | **IaC Security** | `Checkov` | `stage-7/terraform/` | `security/iac/.checkov.yaml` | Non-compliance with CIS AWS Benchmark rules. |
| **Gate 5** | **DAST** | `OWASP ZAP` | CloudFront Live Endpoint | `security/dast/zap-baseline.conf` | Missing security headers (HSTS, CSP, nosniff) or injection leaks. |

---

## 4. Application Hardening & Defense-in-Depth

In Stage 7, the application code (`stage-7/app/server.js`) has been hardened with enterprise defensive controls:

### 1. HTTP Security Headers
Every HTTP response carries strict OWASP-recommended headers:
- `Content-Security-Policy`: Restricts resource loading strictly to `'self'` and trusted CDNs (`fonts.googleapis.com`, `fonts.gstatic.com`).
- `Strict-Transport-Security`: `max-age=31536000; includeSubDomains; preload` (Enforces HTTPS for 1 year).
- `X-Frame-Options`: `DENY` (Prevents clickjacking).
- `X-Content-Type-Options`: `nosniff` (Prevents MIME-sniffing exploits).
- `X-XSS-Protection`: `1; mode=block` (Legacy browser XSS filter).
- `Referrer-Policy`: `strict-origin-when-cross-origin`.
- `Permissions-Policy`: Disables unnecessary hardware APIs (`camera=(), microphone=(), geolocation=()`).

### 2. Application-Layer Rate Limiting
In addition to AWS WAF at the perimeter edge, Express enforces sliding-window IP rate limiting:
- Limit: **120 requests per minute** per client IP.
- Excess requests return `HTTP 429 Too Many Requests` with a `Retry-After` header.

### 3. Strict Input Validation & HTML Sanitization
On order ingestion (`POST /api/orders`):
- Names and addresses are sanitized to strip `<>` tags.
- Email formats are strictly validated against standard RFC 5322 regex.
- Order item quantities and product IDs are validated against positive integer bounds (`1 <= qty <= 100`).

### 4. Dedicated Security Diagnostics Endpoint
A new diagnostic endpoint is available for automated monitoring and compliance auditing:
```bash
curl -s "https://${CF_DOMAIN}/api/security/status" | jq .
```

---

## 5. Local Security Scan Execution Runbook

You can run the entire security scan suite locally or inside CI with the unified runner script:

```bash
# Make script executable
chmod +x stage-7/scripts/run-security-scans.sh

# Run all static security gates (Secrets, SAST, SCA, IaC)
./stage-7/scripts/run-security-scans.sh all

# Run specific gates independently
./stage-7/scripts/run-security-scans.sh secrets
./stage-7/scripts/run-security-scans.sh sast
./stage-7/scripts/run-security-scans.sh sca
./stage-7/scripts/run-security-scans.sh iac

# Run DAST against a deployed CloudFront distribution
./stage-7/scripts/run-security-scans.sh dast https://d123456abcdef.cloudfront.net
```

### Expected Output
```text
================================================================
🛡️  ShopSphere DevSecOps Security Scan Suite (Stage 7)
================================================================
Execution Mode: all
Reports Output: stage-7/security/reports

▶ [Gate 1/5] Running Secrets Detection (Gitleaks)...
✅ PASSED: Gate 1: Secrets Detection (Gitleaks)

▶ [Gate 2/5] Running Static Application Security Testing (Semgrep)...
✅ PASSED: Gate 2: SAST Code Analysis (Semgrep)

▶ [Gate 3/5] Running Software Composition Analysis (Trivy)...
✅ PASSED: Gate 3: SCA Supply Chain (Trivy)

▶ [Gate 4/5] Running Infrastructure as Code Security Scan (Checkov)...
✅ PASSED: Gate 4: IaC Security (Checkov)

================================================================
📊  DevSecOps Quality Gate Summary
================================================================
Total Security Gates Evaluated : 4
Passed Gates                   : 4
Failed Gates                   : 0

🎉 All security quality gates passed successfully!
```

---

## 6. Terraform Verification & Deployment Runbook

```bash
cd stage-7/terraform
terraform init
terraform validate
```

Expected output:
```text
Success! The configuration is valid.
```

### Verification Commands Post-Deployment
```bash
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)
ALB_DNS=$(terraform output -raw alb_dns_name)

# 1. Verify Security Headers
curl -s -I "https://${CF_DOMAIN}/health" | grep -iE "(strict-transport-security|content-security-policy|x-frame-options)"

# 2. Verify Origin Lockdown (Direct access MUST return HTTP 403)
curl -i "http://${ALB_DNS}/health"

# 3. Verify AWS WAF L7 Threat Mitigation (SQLi probe MUST return HTTP 403)
curl -i "https://${CF_DOMAIN}/api/products?id=1%20OR%201=1"

# 4. Verify DevSecOps Status Endpoint
curl -s "https://${CF_DOMAIN}/api/security/status" | jq .
```

---

## 7. Limitations & Technical Debt

1. **Host-Level Container Security:** In Stage 7, code and dependencies are scanned before deployment, but the application runs on native EC2 virtual machines.
2. **Container Image Scanning:** Container image layer scanning (e.g., base OS packages in Debian/Alpine) will be implemented in **Stage 8: Docker**.
3. **Kubernetes Policy Enforcement:** Runtime Admission Controllers (e.g., OPA Gatekeeper / Kyverno) will be introduced in **Stage 9: EKS**.

---

## 8. Next Step: Stage 8 — Docker

With a hardened, security-tested codebase and automated quality gates firmly in place, the application is now ready for standardized containerization:

```
Stage 8 → Docker (Containerization, Multi-Stage Dockerfile Builds, Distroless Images & Image Scanning)
```
