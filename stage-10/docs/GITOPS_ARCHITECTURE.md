# ShopSphere Stage 10: GitOps & Argo CD Architecture

## 1. Architectural Overview

In Stage 10, ShopSphere transitions its continuous delivery model from **CI-driven imperative deployments** (`kubectl apply` executed by Jenkins) to **Declarative GitOps Delivery with Argo CD**.

The cluster state is continuously reconciled against a dedicated GitOps repository ([`shopsphere-aws-scaling-gitops`](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/gitops/)), establishing Git as the single source of truth for all Kubernetes workloads.

```mermaid
flowchart TD
    subgraph Developer_Workspace["Developer Workflow"]
        DEV["Developer"] -->|git commit & push| APP_GIT["Application Repository (shopsphere-aws-scaling)"]
    end

    subgraph CI_Pipeline["Jenkins CI & Quality Gates"]
        APP_GIT -->|Trigger Webhook| JNK["Jenkins Server"]
        JNK -->|1. Test| UNIT["Node.js Native Tests (10/10)"]
        JNK -->|2. SAST| SEMGREP["Semgrep Security Scan"]
        JNK -->|3. Secrets| GITLEAKS["Gitleaks Secret Scan"]
        JNK -->|4. SCA| TRIVY_FS["Trivy Filesystem Scan"]
        JNK -->|5. Build| DOCKER_BUILD["Multi-Stage Alpine Images"]
        JNK -->|6. Container Scan| TRIVY_IMG["Trivy Image Scan"]
        JNK -->|7. Push| ECR["Amazon ECR (Immutable Tags)"]
        JNK -->|8. Update Image Tags| GITOPS_UPDATE["Git Commit (kustomization.yaml)"]
    end

    subgraph GitOps_Control_Plane["GitOps Desired State & Reconciliation"]
        GITOPS_UPDATE -->|git push| GITOPS_REPO["GitOps Repository (shopsphere-aws-scaling-gitops)"]
        GITOPS_REPO -->|Webhook / 3m Poll| ARGO["Argo CD Controller (argocd namespace)"]
        ARGO -->|Compare Desired vs Live| DRIFT{"State Match?"}
        DRIFT -->|OutOfSync| SYNC["Automated Reconciliation (RollingUpdate)"]
        DRIFT -->|Synced| HEALTHY["Cluster In Desired State"]
    end

    subgraph EKS_Runtime["Amazon EKS Cluster (shopsphere-stage9-eks)"]
        SYNC --> POD_FE["frontend-service (:8080)"]
        SYNC --> POD_PROD["product-service (:8081 - 16 Products)"]
        SYNC --> POD_ORD["order-service (:8082)"]
        SYNC --> POD_USER["user-service (:8083)"]
        TGB["AWS Load Balancer Controller (TargetGroupBinding)"] --> ALB["Application Load Balancer"]
    end

    subgraph Persistent_Data["AWS Persistent Tier"]
        POD_PROD --> RDS["Amazon RDS PostgreSQL"]
        POD_PROD --> REDIS["Amazon ElastiCache Redis"]
        POD_ORD --> SQS["Amazon SQS Order Queue"]
    end
```

---

## 2. Key Paradigm Shifts

| Characteristic | Stage 9 (Imperative CI/CD) | Stage 10 (Declarative GitOps) |
| :--- | :--- | :--- |
| **Deployment Trigger** | Jenkins executes `kubectl apply` directly | Jenkins updates image tag in Git; Argo CD reconciles |
| **Cluster Access** | Jenkins requires cluster-admin AWS credentials | Jenkins has **zero direct access** to EKS workloads |
| **Source of Truth** | Ephemeral Jenkins build artifacts | Git repository history (`shopsphere-aws-scaling-gitops`) |
| **Configuration Drift** | Untracked; manual `kubectl` edits go unnoticed | Detected immediately; automatically healed by Argo CD |
| **Rollback Mechanism** | Manual `kubectl rollout undo` or complex script | Clean `git revert` or `git checkout` in GitOps repo |
| **Environment Templating** | Shell `sed` string replacement | Native Kustomize base + production overlay |

---

## 3. GitOps Repository Structure

```text
shopsphere-aws-scaling-gitops/
├── apps/
│   ├── frontend-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── kustomization.yaml
│   ├── product-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── kustomization.yaml
│   ├── order-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   ├── serviceaccount.yaml
│   │   └── kustomization.yaml
│   └── user-service/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── hpa.yaml
│       └── kustomization.yaml
│
├── environments/
│   └── production/
│       ├── kustomization.yaml          <-- Jenkins updates image tags here
│       ├── app-config.yaml             <-- Common non-sensitive config
│       └── target-group-binding.yaml   <-- ALB ingress bindings
│
└── argocd/
    ├── project.yaml                    <-- Argo CD AppProject definition
    └── applications/
        └── shopsphere-production.yaml  <-- Root Application resource
```

---

## 4. Kustomize Overlay Strategy

Kustomize enables modular configuration reuse without templating syntax. The base deployments in `apps/*/deployment.yaml` reference generic image names (`shopsphere-frontend`, `shopsphere-product`, etc.).

In `environments/production/kustomization.yaml`, the production overlay binds them to immutable ECR tags:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: shopsphere-stage9

resources:
  - ../../apps/frontend-service
  - ../../apps/product-service
  - ../../apps/order-service
  - ../../apps/user-service
  - app-config.yaml
  - target-group-binding.yaml

images:
  - name: shopsphere-frontend
    newName: 165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage9-frontend
    newTag: v10.1-64f1c1b8
  - name: shopsphere-product
    newName: 165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage9-product
    newTag: v10.1-64f1c1b8
  - name: shopsphere-order
    newName: 165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage9-order
    newTag: v10.1-64f1c1b8
  - name: shopsphere-user
    newName: 165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage9-user
    newTag: v10.1-64f1c1b8
```
