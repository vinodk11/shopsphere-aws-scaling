#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 9 - EKS Workloads Deployment Script
# Deploys ConfigMaps, Secrets, Microservices, and Ingress to Amazon EKS
# ==============================================================================
set -euo pipefail

CLUSTER_NAME="${1:-shopsphere-stage9-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${2:-latest}"
NAMESPACE="shopsphere-stage9"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🚀 ShopSphere Stage 9 - Kubernetes Workloads Deployment${NC}"
echo -e "${CYAN}================================================================${NC}"
echo "EKS Cluster : ${CLUSTER_NAME}"
echo "AWS Region  : ${AWS_REGION}"
echo "Image Tag   : ${IMAGE_TAG}"
echo "Namespace   : ${NAMESPACE}"

# 1. Update Kubeconfig
echo -e "\n${BLUE}▶ [Step 1/6] Authenticating kubectl with Amazon EKS...${NC}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

# 2. Apply Namespace
echo -e "\n${BLUE}▶ [Step 2/6] Ensuring namespace exists...${NC}"
kubectl apply -f stage-9/kubernetes/namespaces/namespace.yaml

# 3. Apply ConfigMaps and Secrets
echo -e "\n${BLUE}▶ [Step 3/6] Applying Configuration & Credentials...${NC}"
kubectl apply -f stage-9/kubernetes/configmaps/app-config.yaml
kubectl apply -f stage-9/kubernetes/secrets/app-secrets.yaml

# 4. Apply ServiceAccounts (IRSA)
echo -e "\n${BLUE}▶ [Step 4/6] Applying IRSA ServiceAccounts...${NC}"
kubectl apply -f stage-9/kubernetes/order-service/serviceaccount.yaml

# 5. Apply Workloads (Monolith, Product, Order, User Services)
echo -e "\n${BLUE}▶ [Step 5/6] Deploying Microservices & Workloads...${NC}"
kubectl apply -f stage-9/kubernetes/monolith/
kubectl apply -f stage-9/kubernetes/product-service/
kubectl apply -f stage-9/kubernetes/order-service/
kubectl apply -f stage-9/kubernetes/user-service/

# Update image tags if provided
if [ "${IMAGE_TAG}" != "latest" ]; then
    echo "Updating deployments to immutable image tag: ${IMAGE_TAG}"
    kubectl set image deployment/product-service product="*:${IMAGE_TAG}" -n "${NAMESPACE}" || true
    kubectl set image deployment/order-service order="*:${IMAGE_TAG}" -n "${NAMESPACE}" || true
    kubectl set image deployment/user-service user="*:${IMAGE_TAG}" -n "${NAMESPACE}" || true
fi

# 6. Wait for Rollout Status
echo -e "\n${BLUE}▶ [Step 6/6] Awaiting successful Pod rollouts...${NC}"
kubectl rollout status deployment/shopsphere-monolith -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/product-service -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/order-service -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/user-service -n "${NAMESPACE}" --timeout=180s

echo -e "\n${GREEN}🎉 All Stage 9 microservices and workloads successfully deployed to EKS!${NC}"
kubectl get pods,svc -n "${NAMESPACE}"
