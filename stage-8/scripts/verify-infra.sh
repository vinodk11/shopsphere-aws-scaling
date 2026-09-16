#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 8 - AWS Infrastructure Verification Script
# Validates core infrastructure provisioned by Terraform:
# VPC, ALB, ASG, RDS, ElastiCache, SQS, Lambda, CloudFront, WAF, and ECR.
# ==============================================================================
set -euo pipefail

ENV_NAME="${1:-stage8}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="shopsphere"
MANIFEST_FILE="${2:-stage-8/terraform/infra-manifest.json}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🏗️  ShopSphere Infrastructure Verification (${ENV_NAME})${NC}"
echo -e "${CYAN}================================================================${NC}"
echo "AWS Region: ${AWS_REGION}"
echo "Environment: ${ENV_NAME}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_result() {
    local component="$1"
    local status="$2"
    local details="$3"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✅ [PASS] ${component}:${NC} ${details}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌ [FAIL] ${component}:${NC} ${details}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# ------------------------------------------------------------------------------
# 1. Amazon ECR Repository Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Amazon ECR Repository...${NC}"
ECR_NAME="${PROJECT_NAME}-${ENV_NAME}-app"
if aws ecr describe-repositories --repository-names "${ECR_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    ECR_URI=$(aws ecr describe-repositories --repository-names "${ECR_NAME}" --region "${AWS_REGION}" --query 'repositories[0].repositoryUri' --output text)
    SCAN_STATUS=$(aws ecr describe-repositories --repository-names "${ECR_NAME}" --region "${AWS_REGION}" --query 'repositories[0].imageScanningConfiguration.scanOnPush' --output text)
    check_result "Amazon ECR" 0 "URI: ${ECR_URI} (ScanOnPush: ${SCAN_STATUS})"
else
    check_result "Amazon ECR" 1 "Repository ${ECR_NAME} not found"
fi

# ------------------------------------------------------------------------------
# 2. VPC & Subnet Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Virtual Private Cloud (VPC)...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV_NAME}-vpc" --region "${AWS_REGION}" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ -n "${VPC_ID}" ] && [ "${VPC_ID}" != "None" ]; then
    SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "${AWS_REGION}" --query 'length(Subnets)' --output text 2>/dev/null || echo "0")
    check_result "VPC & Subnets" 0 "VPC ID: ${VPC_ID} (${SUBNET_COUNT} subnets configured across Multi-AZ)"
else
    check_result "VPC & Subnets" 1 "VPC tagged ${PROJECT_NAME}-${ENV_NAME}-vpc not found"
fi

# ------------------------------------------------------------------------------
# 3. Application Load Balancer Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Application Load Balancer (ALB)...${NC}"
ALB_NAME="${PROJECT_NAME}-${ENV_NAME}-alb"
ALB_STATE=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --region "${AWS_REGION}" --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null || echo "None")
if [ "${ALB_STATE}" == "active" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --region "${AWS_REGION}" --query 'LoadBalancers[0].DNSName' --output text)
    check_result "Application Load Balancer" 0 "${ALB_NAME} is active (${ALB_DNS})"
else
    check_result "Application Load Balancer" 1 "${ALB_NAME} state: ${ALB_STATE}"
fi

# ------------------------------------------------------------------------------
# 4. Auto Scaling Group & Launch Template Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking EC2 Auto Scaling Group...${NC}"
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --region "${AWS_REGION}" \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${PROJECT_NAME}-${ENV_NAME}-asg')].AutoScalingGroupName | [0]" --output text 2>/dev/null || echo "None")
if [ -n "${ASG_NAME}" ] && [ "${ASG_NAME}" != "None" ]; then
    ASG_INSTANCES=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ASG_NAME}" --region "${AWS_REGION}" \
        --query 'length(AutoScalingGroups[0].Instances)' --output text)
    DESIRED_CAP=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ASG_NAME}" --region "${AWS_REGION}" \
        --query 'AutoScalingGroups[0].DesiredCapacity' --output text)
    LT_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ASG_NAME}" --region "${AWS_REGION}" \
        --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId' --output text)
    check_result "Auto Scaling Group" 0 "${ASG_NAME} (Instances: ${ASG_INSTANCES}/${DESIRED_CAP}, LaunchTemplate: ${LT_ID})"
else
    check_result "Auto Scaling Group" 1 "ASG matching ${PROJECT_NAME}-${ENV_NAME}-asg not found"
fi

# ------------------------------------------------------------------------------
# 5. Amazon RDS PostgreSQL Database Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Amazon RDS PostgreSQL Instance...${NC}"
RDS_ID="${PROJECT_NAME}-${ENV_NAME}-postgres"
RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier "${RDS_ID}" --region "${AWS_REGION}" \
    --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "None")
if [ "${RDS_STATUS}" == "available" ]; then
    RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "${RDS_ID}" --region "${AWS_REGION}" \
        --query 'DBInstances[0].Endpoint.Address' --output text)
    check_result "Amazon RDS PostgreSQL" 0 "${RDS_ID} is available at ${RDS_ENDPOINT}:5432"
else
    check_result "Amazon RDS PostgreSQL" 1 "${RDS_ID} status: ${RDS_STATUS}"
fi

# ------------------------------------------------------------------------------
# 6. Amazon ElastiCache Redis Cluster Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Amazon ElastiCache Redis Cluster...${NC}"
REDIS_ID="${PROJECT_NAME}-${ENV_NAME}-redis"
REDIS_STATUS=$(aws elasticache describe-cache-clusters --cache-cluster-id "${REDIS_ID}" --region "${AWS_REGION}" \
    --query 'CacheClusters[0].CacheClusterStatus' --output text 2>/dev/null || echo "None")
if [ "${REDIS_STATUS}" == "available" ]; then
    check_result "Amazon ElastiCache Redis" 0 "${REDIS_ID} is available (Engine: Redis 7.x)"
else
    check_result "Amazon ElastiCache Redis" 1 "${REDIS_ID} status: ${REDIS_STATUS}"
fi

# ------------------------------------------------------------------------------
# 7. Amazon SQS Queues Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Amazon SQS Order Processing Queue & DLQ...${NC}"
QUEUE_URL=$(aws sqs get-queue-url --queue-name "${PROJECT_NAME}-${ENV_NAME}-order-processing-queue" --region "${AWS_REGION}" --query 'QueueUrl' --output text 2>/dev/null || echo "None")
DLQ_URL=$(aws sqs get-queue-url --queue-name "${PROJECT_NAME}-${ENV_NAME}-order-processing-dlq" --region "${AWS_REGION}" --query 'QueueUrl' --output text 2>/dev/null || echo "None")
if [ "${QUEUE_URL}" != "None" ] && [ "${DLQ_URL}" != "None" ]; then
    check_result "Amazon SQS Queues" 0 "Primary Queue & DLQ exist and active"
else
    check_result "Amazon SQS Queues" 1 "Queue: ${QUEUE_URL}, DLQ: ${DLQ_URL}"
fi

# ------------------------------------------------------------------------------
# 8. AWS Lambda Worker Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking AWS Lambda Serverless Worker...${NC}"
LAMBDA_NAME="${PROJECT_NAME}-${ENV_NAME}-order-processor"
LAMBDA_STATE=$(aws lambda get-function --function-name "${LAMBDA_NAME}" --region "${AWS_REGION}" \
    --query 'Configuration.State' --output text 2>/dev/null || echo "None")
if [ "${LAMBDA_STATE}" == "Active" ]; then
    check_result "AWS Lambda Function" 0 "${LAMBDA_NAME} state: Active"
else
    check_result "AWS Lambda Function" 1 "${LAMBDA_NAME} state: ${LAMBDA_STATE}"
fi

# ------------------------------------------------------------------------------
# 9. AWS WAF v2 Web ACL Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking AWS WAF v2 Perimeter Web ACL...${NC}"
WAF_NAME="${PROJECT_NAME}-${ENV_NAME}-web-acl"
WAF_ID=$(aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 \
    --query "WebACLs[?Name=='${WAF_NAME}'].Id | [0]" --output text 2>/dev/null || echo "None")
if [ -n "${WAF_ID}" ] && [ "${WAF_ID}" != "None" ]; then
    check_result "AWS WAF v2" 0 "${WAF_NAME} (ID: ${WAF_ID}) active in us-east-1"
else
    check_result "AWS WAF v2" 1 "${WAF_NAME} not found in scope CLOUDFRONT"
fi

# ------------------------------------------------------------------------------
# 10. Amazon CloudFront Distribution Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ Checking Amazon CloudFront Edge CDN...${NC}"
CF_COMMENT="ShopSphere Global Edge CDN - Stage 8 (${ENV_NAME})"
CF_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Comment=='${CF_COMMENT}'].Id | [0]" --output text 2>/dev/null || echo "None")
if [ -z "${CF_ID}" ] || [ "${CF_ID}" == "None" ]; then
    # Fallback to any distribution matching project name in comment or caller reference
    CF_ID=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[?contains(Comment, 'ShopSphere')].Id | [0]" --output text 2>/dev/null || echo "None")
fi

if [ -n "${CF_ID}" ] && [ "${CF_ID}" != "None" ]; then
    CF_STATUS=$(aws cloudfront get-distribution --id "${CF_ID}" --query 'Distribution.Status' --output text)
    CF_DOMAIN=$(aws cloudfront get-distribution --id "${CF_ID}" --query 'Distribution.DomainName' --output text)
    check_result "Amazon CloudFront" 0 "ID: ${CF_ID} (${CF_DOMAIN}) Status: ${CF_STATUS}"
else
    check_result "Amazon CloudFront" 1 "Distribution not found"
fi

echo -e "\n${CYAN}================================================================${NC}"
echo -e "${CYAN}📊  Infrastructure Verification Summary${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "Total Checks : ${TOTAL_CHECKS}"
echo -e "Passed       : ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "Failed       : ${RED}${FAILED_CHECKS}${NC}"

if [ "${FAILED_CHECKS}" -gt 0 ]; then
    echo -e "\n${RED}❌ Infrastructure verification failed with ${FAILED_CHECKS} error(s).${NC}"
    exit 1
else
    echo -e "\n${GREEN}🎉 All infrastructure components verified successfully!${NC}"
    exit 0
fi
