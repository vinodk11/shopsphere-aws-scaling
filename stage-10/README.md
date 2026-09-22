# ShopSphere Stage 10: GitOps Continuous Delivery with Argo CD

## Overview

**Stage 10** represents the modern enterprise pinnacle of the ShopSphere AWS scaling journey, introducing **GitOps Continuous Delivery with Argo CD** on top of the Amazon EKS microservices architecture.

Application deployment responsibility is permanently shifted from the Jenkins CI server to **Argo CD**, ensuring that all runtime configurations are strictly declared in and continuously reconciled from the GitOps desired state repository ([`shopsphere-gitops`](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/gitops/)).

---

## What's New in Stage 10

### 1. Application Evolution
* **Landing Page Customer Gateway**:
  * The ShopSphere landing page features an integrated **Sign In & Sign Up** customer portal right on the home page.
  * Unauthenticated users are greeted with a dual-tab authentication card (Sign In, Create Account, 1-Click Demo Login, and Enterprise SSO via AWS IAM / Google / GitHub).
  * Upon signing in or signing up, the view transitions to unlock the **Full 16-Product Enterprise Catalog** and shopping cart.
* **Expanded 16-Product Catalog**:
  * Product Service catalog expanded from 6 items to 16 enterprise cloud tech items spanning Audio, Wearables, Smart Home, Computer Peripherals, Developer Gear, and Cloud Networking.
  * Redis inventory caching and PostgreSQL persistence.

### 2. GitOps Continuous Delivery
* **Argo CD Controller**:
  * Installed in namespace `argocd` via Terraform Helm module.
  * Continuously polls Git and automatically reconciles cluster workloads with `selfHeal: true`.
* **Zero Imperative Workload Deployments**:
  * Jenkins pipeline (`Jenkinsfile-app`) no longer calls `kubectl apply` or `helm upgrade`.
  * Jenkins tests, builds, and pushes Docker images to ECR, then commits immutable image tags to `environments/production/kustomization.yaml` in the GitOps repository.
* **Kustomize Modular Architecture**:
  * Separate base definitions under [`apps/`](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/gitops/apps/) and environment overlays under [`environments/production/`](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/gitops/environments/production/).

---

## Directory Structure

```text
stage-10/
├── services/                          # Microservices Source Code
│   ├── frontend/                      # Web App + Landing Page Sign In/Up Gateway
│   ├── product/                       # 16-Product Catalog + Redis Cache + PostgreSQL
│   ├── order/                         # Async Order Processing + SQS
│   └── user/                          # Auth, Registration & Enterprise SSO
│
├── gitops/                            # GitOps Desired State (shopsphere-gitops)
│   ├── apps/                          # Kustomize Base Manifests per Microservice
│   │   ├── frontend-service/
│   │   ├── product-service/
│   │   ├── order-service/
│   │   └── user-service/
│   ├── environments/production/       # Production Kustomize Overlay & Ingress
│   └── argocd/                        # AppProject & Application CRDs
│
├── terraform/                         # Infrastructure as Code
│   ├── modules/
│   │   ├── eks/                       # EKS Cluster
│   │   ├── node-group/                # Multi-AZ Managed Nodes
│   │   ├── alb-routing/               # ALB Ingress Rules & Target Groups
│   │   ├── iam/                       # IRSA Policies
│   │   ├── ecr/                       # ECR Repositories
│   │   └── argocd/                    # Argo CD Helm Provisioning
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── Jenkinsfile-infra                  # Infrastructure Pipeline (EKS + Argo CD)
├── Jenkinsfile-app                    # GitOps CI Pipeline (Build -> Test -> ECR -> GitOps Commit)
│
└── docs/                              # Comprehensive Technical Documentation
    ├── GITOPS_ARCHITECTURE.md
    ├── ARGOCD_SETUP_GUIDE.md
    ├── ROLLBACK_PROCEDURE.md
    ├── SELF_HEALING_DEMO.md
    └── DEPLOYMENT_AND_VALIDATION.md
```

---

## Technical Documentation Links

* [GitOps Architecture & Workflow](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/docs/GITOPS_ARCHITECTURE.md)
* [Argo CD Setup & Operational Guide](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/docs/ARGOCD_SETUP_GUIDE.md)
* [Git-Driven Rollback Procedure](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/docs/ROLLBACK_PROCEDURE.md)
* [Drift Detection & Self-Healing Demonstration](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/docs/SELF_HEALING_DEMO.md)
* [Complete Deployment & Validation Guide](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/docs/DEPLOYMENT_AND_VALIDATION.md)
