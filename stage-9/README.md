# ShopSphere Stage 9 v2 — EKS Progressive Microservices Migration

Stage 8 is live on EC2/ASG (Docker Monolith). Stage 9 is additive: an Amazon EKS cluster is created alongside Stage 8, and the existing Stage 8 Application Load Balancer (ALB) remains the production entry point.

The old monolith has been **completely eliminated from Stage 9**, replaced by a decoupled, cloud-native **Frontend UI microservice** and backend business services with **Enterprise Single Sign-On (SSO)**.

---

## 4 Decoupled Microservices in Stage 9

1. **Frontend Service** (`services/frontend`):
   * Port `8080`, NodePort `30080` (Target Group: `shopsphere-stage9-eks-fe-tg`).
   * Lightweight container serving the Stage 9 UI, live microservices architecture visualizer, and SSO authentication portal.
2. **Product Service** (`services/product`):
   * Port `8081`, NodePort `30081` (Target Group: `shopsphere-stage9-eks-prod-tg`).
   * Handles `/api/products*` with PostgreSQL RDS and sub-millisecond ElastiCache Redis catalog caching.
3. **Order Service** (`services/order`):
   * Port `8082`, NodePort `30082` (Target Group: `shopsphere-stage9-eks-ord-tg`).
   * Handles `/api/orders*` with transactional PostgreSQL RDS storage and asynchronous Amazon SQS event dispatch via IRSA.
4. **User & SSO Service** (`services/user`):
   * Port `8083`, NodePort `30083` (Target Group: `shopsphere-stage9-eks-user-tg`).
   * Handles `/api/users*` with User Registration, Sign-In, and Enterprise Single Sign-On (AWS IAM, Google, GitHub SSO federation).

---

## Traffic & Ingress Routing Model

```text
CloudFront CDN (X-Origin-Verify) → AWS WAF → Existing Stage 8 ALB
                                                  │
         ┌────────────────────────────────────────┼────────────────────────────────────────┐
         │ (Priority 5)                           │ (Priority 6)                           │ (Priority 7)
         ▼                                        ▼                                        ▼
  /api/products*                           /api/orders*                             /api/users*
Product Microservice                     Order Microservice                      User & SSO Service
   (Port 8081)                              (Port 8082)                             (Port 8083)

                                                  │
                                                  │ (Priority 9: Catch-All /* with Header)
                                                  ▼
                                       Blue / Green Weighted Shift
                                                  │
                         ┌────────────────────────┴────────────────────────┐
                         ▼                                                 ▼
                Blue Weight (100% ➔ 0%)                           Green Weight (0% ➔ 100%)
                 Stage 8 EC2 ASG Monolith                          Stage 9 EKS Frontend Service
               ("Stage 8 Containerization")                        ("Stage 9 EKS & Microservices")
```

### ALB Listener Rule Priorities:
* **Priority 5**: `/api/products*` ➔ `product-service` (Port `30081`)
* **Priority 6**: `/api/orders*` ➔ `order-service` (Port `30082`)
* **Priority 7**: `/api/users*` ➔ `user-service` (Port `30083`)
* **Priority 9**: `/*` (CloudFront Verified) ➔ Blue/Green Weighted Shift (`stage8-tg` vs `stage9-frontend-tg`)
* **Priority 10**: Stage 8 fallback rule
* **Default**: 403 Forbidden (Direct ALB bypass locked down)

---

## Key Improvements Over Initial Stage 9

1. **Monolith Completely Removed**: Replaced by dedicated `frontend-service` container in EKS displaying the Stage 9 UI and live microservices topology.
2. **Enterprise Single Sign-On (SSO)**: Built into `user-service` with endpoints for Signup, Login, and SSO federation.
3. **No ALB Rule Collision**: Weighted rule placed at **Priority 9**, guaranteeing that CloudFront requests shift to Stage 9 Green rather than being hijacked by Stage 8's Priority 10.
4. **TargetGroupBinding**: AWS Load Balancer Controller binds Kubernetes pods/services to Target Groups automatically without custom shell scripts.
5. **NodePort Security Group Automation**: ALB security group is authorized on NodePorts `30000-32767` in Terraform, ensuring target health checks pass instantly.
6. **Automated DB Migration**: Order service auto-migrates missing columns (`items`, `sqs_message_id`, `shipping_address`) without breaking existing Stage 8 tables.

---

## Deployment Workflow

### 1. Infrastructure Pipeline (`Jenkinsfile-infra`)
Run with `ACTION=plan`, then `ACTION=apply`. Provisions EKS, Managed Nodes, ECR repos, IAM IRSA roles, Target Groups, and installs AWS Load Balancer Controller via Helm.

### 2. Application Pipeline (`Jenkinsfile-app`)
* Builds, tests, scans (Trivy), and pushes all 4 microservice containers (`frontend`, `product`, `order`, `user`) to ECR.
* Deploys manifests to EKS namespace `shopsphere-stage9`.
* Initiates progressive traffic migration:
  ```text
  100-0  ➔ Initial deploy (Stage 8 at 100%, Stage 9 at 0%)
  90-10  ➔ Canary test (10% Green)
  50-50  ➔ Balanced migration
  0-100  ➔ Full EKS Cutover (100% Green)
  ```
