# ShopSphere: Cloud Architecture Evolution on AWS

Welcome to the **ShopSphere AWS Scaling** repository. This project demonstrates the step-by-step architectural evolution of an enterprise e-commerce platform from a single-server monolith to an elastic, highly available, containerized, and Kubernetes-orchestrated system on Amazon Web Services.

---

## 🗺️ Architecture Roadmap

```
Stage 1: Single EC2 Instance + Colocated Database (Baseline Monolith)
   ↓
Stage 2: EC2 Application Tier + Managed Amazon RDS PostgreSQL (Database Decoupling)
   ↓
Stage 3: ALB + Auto Scaling Group + Multi-EC2 + Amazon RDS (Horizontal Scaling & High Availability)
   ↓
Stage 4: Amazon ElastiCache / Redis (In-Memory Caching & Session Management)
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

---

## 📂 Repository Stages

| Stage | Path | Architecture Highlights | Status |
| :--- | :--- | :--- | :--- |
| **Stage 1** | [`stage-1/`](stage-1/README.md) | Single EC2, local PostgreSQL, Nginx reverse proxy | ✅ Completed |
| **Stage 2** | [`stage-2/`](stage-2/README.md) | EC2 compute, decoupled Amazon RDS PostgreSQL, multi-tier VPC | ✅ Completed |
| **Stage 3** | [`stage-3/`](stage-3/README.md) | Application Load Balancer, Multi-AZ Auto Scaling Group, Amazon RDS | ✅ Completed |
| **Stage 4** | [`stage-4/`](stage-4/README.md) | In-Memory Amazon ElastiCache Redis, Cache-Aside, Sub-ms Latency | ✅ Completed |

---

## 🚀 CI/CD Automation

This repository includes:
- A root [`Jenkinsfile`](Jenkinsfile) capable of dynamically planning, applying, or destroying any stage (`stage-1`, `stage-2`, `stage-3`, or `stage-4`) using containerized Terraform with approval gates and automated health verification.
- Dedicated standalone pipelines in each stage directory (`stage-1/Jenkinsfile`, `stage-2/Jenkinsfile`, `stage-3/Jenkinsfile`, `stage-4/Jenkinsfile`).

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