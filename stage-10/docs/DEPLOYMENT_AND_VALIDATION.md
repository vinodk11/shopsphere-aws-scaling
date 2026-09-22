# ShopSphere Stage 10: Complete Deployment & Validation Guide

## 1. Prerequisites & Environment Check

Before initiating Stage 10 deployment, ensure the following core tools are installed on your workstation or Jenkins controller:
* AWS CLI v2 (`aws --version`)
* kubectl v1.30+ (`kubectl version --client`)
* Helm v3.12+ (`helm version`)
* Terraform v1.5+ (`terraform version`)

---

## 2. Infrastructure Pipeline Execution (`stage-10-infra`)

The infrastructure pipeline provisions the Stage 10 Amazon EKS cluster, managed worker nodes, ALB rules, and bootstraps Argo CD.

### Via Jenkins Web UI or CLI
```bash
# Trigger infrastructure pipeline
ssh -i /home/vagrant/.ssh/CloudForge.pem ubuntu@3.80.137.129 \
  "java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin build stage-10-infra -p ACTION=apply -p AUTO_APPROVE=true"
```

### Direct Terraform Execution (Alternative)
```bash
cd stage-10/terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out=stage10.tfplan
terraform apply stage10.tfplan
terraform output -json > stage10-outputs.json
```

---

## 3. GitOps Repository Setup (`shopsphere-aws-scaling-gitops`)

Initialize the GitOps repository containing the Kustomize manifests:

```bash
mkdir -p /vagrant/dev_projects/shopsphere-aws-scaling-gitops
cp -r /vagrant/dev_projects/shopsphere-aws-scaling/stage-10/gitops/* /vagrant/dev_projects/shopsphere-aws-scaling-gitops/
cd /vagrant/dev_projects/shopsphere-aws-scaling-gitops
git init -b main
git config user.name "ShopSphere GitOps Admin"
git config user.email "gitops@shopsphere.io"
git add .
git commit -m "feat: bootstrap stage-10 gitops desired state manifests"
```

If using a remote GitHub repository:
```bash
git remote add origin https://github.com/vinodk11/shopsphere-aws-scaling-gitops.git
git push -u origin main
```

---

## 4. Application CI Pipeline Execution (`stage-10-app`)

The application pipeline builds, tests, scans, pushes images to ECR, and commits the new image tags into `shopsphere-aws-scaling-gitops`:

```bash
# Trigger application pipeline
ssh -i /home/vagrant/.ssh/CloudForge.pem ubuntu@3.80.137.129 \
  "java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin build stage-10-app"
```

---

## 5. End-to-End System Validation

### A. Verify Argo CD Status
```bash
# Verify Argo CD pods
kubectl get pods -n argocd

# Verify Argo CD Application sync status
kubectl get application shopsphere-production -n argocd -o wide
```
Expected output:
```text
NAME                    SYNC STATUS   HEALTH STATUS   REVISION   PATH
shopsphere-production   Synced        Healthy         main       environments/production
```

### B. Verify Kubernetes Microservices Pods
```bash
kubectl get pods -n shopsphere-stage9 -o wide
```
Expected: 8/8 pods Running (2x frontend, 2x product, 2x order, 2x user).

### C. Verify TargetGroupBindings & ALB Health
```bash
# Check TargetGroupBindings
kubectl get targetgroupbindings -n shopsphere-stage9

# Check Target Group Health on AWS
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?contains(TargetGroupName, 'shopsphere-stage9-eks-prod-tg')].TargetGroupArn" --output text) \
  --region us-east-1
```
Expected: All worker nodes report `TargetHealth.State: healthy`.

### D. Validate Frontend Landing Page (Sign In / Sign Up Gateway)
Access the live CloudFront or ALB endpoint:
```bash
curl -s https://d33f8dq17c8295.cloudfront.net/ | grep -i "landingAuthSection"
```
* Unauthenticated: landing page presents **Sign In / Sign Up** tabs and locked teaser.
* Authenticated: loads all **16 enterprise products** with stock levels and cart checkout.

### E. Validate Expanded 16-Product Catalog
```bash
curl -s https://d33f8dq17c8295.cloudfront.net/api/products | jq '.count, .data[0].name, .data[15].name'
```
Expected:
```text
16
"CloudBeats ANC Wireless Headphones"
"KubeKey FIDO2 Hardware Security Key"
```
