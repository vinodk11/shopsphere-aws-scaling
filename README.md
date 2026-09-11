# ShopSphere: Cloud Architecture Evolution on AWS

Welcome to the **ShopSphere AWS Scaling** repository. This project demonstrates the step-by-step architectural evolution of an enterprise e-commerce platform from a single-server monolith to an elastic, highly available, containerized, and Kubernetes-orchestrated system on Amazon Web Services.

---

## 🗺️ Architecture Roadmap

```
Stage 1  → Monolith + EC2
Stage 2  → RDS PostgreSQL (Database Decoupling)
Stage 3  → ALB + Auto Scaling Group (Horizontal Scaling & High Availability)
Stage 4  → Redis / ElastiCache (In-Memory Caching & Session Management)
Stage 5  → SQS + Lambda (Decoupled Asynchronous Order Processing)
Stage 6  → CloudFront + WAF (Global Edge CDN & Web Security)
Stage 7  → DevSecOps (SAST, DAST, SCA, Secrets Detection, Image Scanning, Pipeline Security)
Stage 8  → Docker (Containerization & Multi-Stage Builds)
Stage 9  → EKS (Kubernetes Container Orchestration & Microservices)
Stage 10 → GitOps / Argo CD (Continuous Delivery & Full Observability)
```

---

## 📂 Repository Stages

| Stage | Path | Architecture Highlights | Status |
| :--- | :--- | :--- | :--- |
| **Stage 1** | [`stage-1/`](stage-1/README.md) | Single EC2, local PostgreSQL, Nginx reverse proxy | ✅ Completed |
| **Stage 2** | [`stage-2/`](stage-2/README.md) | EC2 compute, decoupled Amazon RDS PostgreSQL, multi-tier VPC | ✅ Completed |
| **Stage 3** | [`stage-3/`](stage-3/README.md) | Application Load Balancer, Multi-AZ Auto Scaling Group, Amazon RDS | ✅ Completed |
| **Stage 4** | [`stage-4/`](stage-4/README.md) | In-Memory Amazon ElastiCache Redis, Cache-Aside, Sub-ms Latency | ✅ Completed |
| **Stage 5** | [`stage-5/`](stage-5/README.md) | Amazon SQS + AWS Lambda, Non-blocking Checkouts, DLQ Redrive | ✅ Completed |

---

## 🚀 CI/CD Automation

This repository includes:
- A root [`Jenkinsfile`](Jenkinsfile) capable of dynamically planning, applying, or destroying any stage (`stage-1`, `stage-2`, `stage-3`, `stage-4`, or `stage-5`) using containerized Terraform with approval gates and automated health verification.
- Dedicated standalone pipelines in each stage directory (`stage-1/Jenkinsfile`, `stage-2/Jenkinsfile`, `stage-3/Jenkinsfile`, `stage-4/Jenkinsfile`, `stage-5/Jenkinsfile`).

### Required Jenkins Plugins

To run the declarative pipelines in Jenkins, install the following plugins (**Manage Jenkins** &rarr; **Plugins** &rarr; **Available plugins**):

| Plugin Name | Plugin ID | Requirement |
| :--- | :--- | :--- |
| **Pipeline** | `workflow-aggregator` | Core Declarative Pipeline engine |
| **Git** | `git` | SCM repository cloning |
| **AnsiColor** | `ansicolor` | **Critical!** Terminal ANSI color decoding for `ansiColor('xterm')` |
| **Pipeline: Input Step** | `pipeline-input-step` | Manual approval gates before Terraform apply/destroy |
| **Docker Pipeline** | `docker-workflow` | Optional container integration |

### Jenkins Server Host Configuration

The pipelines run Terraform inside Docker containers. Ensure the following on your Jenkins server:

1. **Start Docker:** `sudo systemctl enable --now docker`
2. **Grant Docker Access:** `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`
3. **AWS IAM Access:** Attach an IAM Role with EC2, VPC, and RDS permissions to the Jenkins EC2 instance.