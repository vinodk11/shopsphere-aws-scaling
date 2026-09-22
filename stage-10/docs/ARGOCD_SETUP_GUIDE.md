# ShopSphere Stage 10: Argo CD Setup & Operational Guide

## 1. Installation Overview

Argo CD is provisioned on the Amazon EKS cluster (`shopsphere-stage9-eks`) using Terraform's `helm_release` resource pointing to the official `argo-helm` repository:

* **Helm Chart**: `argo/argo-cd` (v7.7.16)
* **Namespace**: `argocd`
* **Architecture**: High-availability microservices (server, repo-server, application-controller, dex-server, redis)

---

## 2. Terraform Provisioning

The Argo CD module is declared in [`stage-10/terraform/modules/argocd/main.tf`](file:///vagrant/dev_projects/shopsphere-aws-scaling/stage-10/terraform/modules/argocd/main.tf).

### Manual CLI Installation (Alternative)
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name shopsphere-stage9-eks

# Create namespace
kubectl create namespace argocd

# Add Argo CD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo CD
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --set server.extraArgs="{--insecure}" \
  --wait
```

---

## 3. Retrieving Initial Admin Credentials

Argo CD generates a random base64-encoded initial admin password stored in Kubernetes secret `argocd-initial-admin-secret`.

To retrieve the plaintext password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

* **Default Username**: `admin`
* **Default Password**: Retrieved via command above

---

## 4. Secure Access to Argo CD Web UI & CLI

### Option A: Local Port-Forwarding (Recommended for Ops)
To access the Argo CD Web UI without exposing administrative ports to the public Internet:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Open your browser at: **`http://localhost:8080`**

### Option B: Argo CD CLI Login
```bash
# Download CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Authenticate via port-forward
argocd login localhost:8080 --username admin --password <RETRIEVED_PASSWORD> --insecure
```

---

## 5. Bootstrapping the ShopSphere Application

Once Argo CD is online, apply the AppProject and Application manifests:

```bash
# 1. Create ShopSphere AppProject
kubectl apply -f stage-10/gitops/argocd/project.yaml

# 2. Register ShopSphere Production Application
kubectl apply -f stage-10/gitops/argocd/applications/shopsphere-production.yaml
```

Verify application status:
```bash
kubectl get application shopsphere-production -n argocd
```

Output:
```text
NAME                    SYNC STATUS   HEALTH STATUS
shopsphere-production   Synced        Healthy
```
