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
PROJECT_NAME="shopsphere"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🚀 ShopSphere Stage 9 - Kubernetes Workloads Deployment${NC}"
echo -e "${CYAN}================================================================${NC}"
echo "EKS Cluster : ${CLUSTER_NAME}"
echo "AWS Region  : ${AWS_REGION}"
echo "Image Tag   : ${IMAGE_TAG}"
echo "Namespace   : ${NAMESPACE}"

# 1. Update Kubeconfig
echo -e "\n${BLUE}▶ [Step 1/7] Authenticating kubectl with Amazon EKS...${NC}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

# 2. Apply Namespace
echo -e "\n${BLUE}▶ [Step 2/7] Ensuring namespace exists...${NC}"
kubectl apply -f stage-9/kubernetes/namespaces/namespace.yaml

# 3. Apply ConfigMaps and Secrets
echo -e "\n${BLUE}▶ [Step 3/7] Applying Configuration & Credentials...${NC}"
kubectl apply -f stage-9/kubernetes/configmaps/app-config.yaml
kubectl apply -f stage-9/kubernetes/secrets/app-secrets.yaml

# 4. Apply ServiceAccounts (IRSA)
echo -e "\n${BLUE}▶ [Step 4/7] Applying IRSA ServiceAccounts...${NC}"
kubectl apply -f stage-9/kubernetes/order-service/serviceaccount.yaml

# 5. Apply Workloads (Monolith, Product, Order, User Services)
echo -e "\n${BLUE}▶ [Step 5/7] Deploying Microservices & Workloads...${NC}"
kubectl apply -f stage-9/kubernetes/monolith/
kubectl apply -f stage-9/kubernetes/product-service/
kubectl apply -f stage-9/kubernetes/order-service/
kubectl apply -f stage-9/kubernetes/user-service/

# Update image tags if provided
if [ "${IMAGE_TAG}" != "latest" ]; then
    echo "Updating deployments to immutable image tag: ${IMAGE_TAG}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_PREFIX="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    kubectl set image deployment/product-service product="${ECR_PREFIX}/shopsphere-stage9-product:${IMAGE_TAG}" -n "${NAMESPACE}" || true
    kubectl set image deployment/order-service order="${ECR_PREFIX}/shopsphere-stage9-order:${IMAGE_TAG}" -n "${NAMESPACE}" || true
    kubectl set image deployment/user-service user="${ECR_PREFIX}/shopsphere-stage9-user:${IMAGE_TAG}" -n "${NAMESPACE}" || true
fi

# 6. Wait for Rollout Status
echo -e "\n${BLUE}▶ [Step 6/7] Awaiting successful Pod rollouts...${NC}"
kubectl rollout status deployment/shopsphere-monolith -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/product-service -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/order-service -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/user-service -n "${NAMESPACE}" --timeout=180s

# 7. Register Worker Nodes into ALB Target Groups & Ensure SG Ingress
echo -e "\n${BLUE}▶ [Step 7/7] Registering EKS Worker Nodes into Stage 9 Target Groups...${NC}"
NODE_IDS=$(aws ec2 describe-instances --region "${AWS_REGION}" \
    --filters "Name=tag:eks:cluster-name,Values=${CLUSTER_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" --output text || echo "")

if [ -n "${NODE_IDS}" ]; then
    echo "Discovered running worker nodes: ${NODE_IDS}"

    # Ensure ALB SG ingress to worker cluster SG
    ALB_SG=$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
        --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}-stage8-alb')].SecurityGroups[0] | [0]" --output text 2>/dev/null || echo "")
    CLUSTER_SG=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
        --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text 2>/dev/null || echo "")

    if [ -n "${ALB_SG}" ] && [ -n "${CLUSTER_SG}" ] && [ "${ALB_SG}" != "None" ] && [ "${CLUSTER_SG}" != "None" ]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "${CLUSTER_SG}" \
            --protocol tcp \
            --port 30000-32767 \
            --source-group "${ALB_SG}" \
            --region "${AWS_REGION}" 2>/dev/null || true
    fi

    # Discover Target Groups
    MONO_TG=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
        --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-mono-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")
    PROD_TG=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
        --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-prod-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")
    ORD_TG=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
        --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-ord-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

    MONO_TARGETS=""
    PROD_TARGETS=""
    ORD_TARGETS=""
    for nid in ${NODE_IDS}; do
        MONO_TARGETS="${MONO_TARGETS} Id=${nid},Port=30080"
        PROD_TARGETS="${PROD_TARGETS} Id=${nid},Port=30081"
        ORD_TARGETS="${ORD_TARGETS} Id=${nid},Port=30082"
    done

    if [ -n "${MONO_TG}" ] && [ "${MONO_TG}" != "None" ]; then
        aws elbv2 register-targets --target-group-arn "${MONO_TG}" --targets ${MONO_TARGETS} --region "${AWS_REGION}" 2>/dev/null || true
    fi
    if [ -n "${PROD_TG}" ] && [ "${PROD_TG}" != "None" ]; then
        aws elbv2 register-targets --target-group-arn "${PROD_TG}" --targets ${PROD_TARGETS} --region "${AWS_REGION}" 2>/dev/null || true
    fi
    if [ -n "${ORD_TG}" ] && [ "${ORD_TG}" != "None" ]; then
        aws elbv2 register-targets --target-group-arn "${ORD_TG}" --targets ${ORD_TARGETS} --region "${AWS_REGION}" 2>/dev/null || true
    fi
    echo -e "${GREEN}✅ EKS worker nodes successfully registered to Stage 9 Target Groups.${NC}"
else
    echo -e "${YELLOW}⚠️ No worker nodes discovered via cluster tag.${NC}"
fi

echo -e "\n${GREEN}🎉 All Stage 9 microservices and workloads successfully deployed and registered!${NC}"
kubectl get pods,svc -n "${NAMESPACE}"
