#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 8 - ASG Rolling Deployment & Instance Refresh Script
# Updates Launch Template with immutable Docker image tag, initiates ASG
# rolling instance refresh, and waits for successful completion.
# ==============================================================================
set -euo pipefail

IMAGE_TAG="${1:-}"
ENV_NAME="${2:-stage8}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="shopsphere"
POLL_INTERVAL=20
MAX_WAIT_MINUTES=25

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🚀 ShopSphere ASG Rolling Container Deployment (Instance Refresh)${NC}"
echo -e "${CYAN}================================================================${NC}"

if [ -z "${IMAGE_TAG}" ]; then
    echo -e "${RED}❌ Error: Target Docker image tag must be provided as first argument.${NC}"
    echo "Usage: $0 <image-tag> [environment]"
    exit 1
fi

echo "Target Image Tag : ${IMAGE_TAG}"
echo "Environment      : ${ENV_NAME}"
echo "AWS Region       : ${AWS_REGION}"

# ------------------------------------------------------------------------------
# 1. Discover Auto Scaling Group
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ [Step 1/5] Discovering Auto Scaling Group...${NC}"
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --region "${AWS_REGION}" \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${PROJECT_NAME}-${ENV_NAME}-asg')].AutoScalingGroupName | [0]" --output text 2>/dev/null || echo "")

if [ -z "${ASG_NAME}" ] || [ "${ASG_NAME}" == "None" ]; then
    # Fallback to stage6 if migrating
    ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --region "${AWS_REGION}" \
        --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${PROJECT_NAME}-stage6-asg')].AutoScalingGroupName | [0]" --output text 2>/dev/null || echo "")
fi

if [ -z "${ASG_NAME}" ] || [ "${ASG_NAME}" == "None" ]; then
    # General fallback for any persistent shopsphere ASG
    ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --region "${AWS_REGION}" \
        --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${PROJECT_NAME}')].AutoScalingGroupName | [0]" --output text 2>/dev/null || echo "")
fi

if [ -z "${ASG_NAME}" ] || [ "${ASG_NAME}" == "None" ]; then
    echo -e "${RED}❌ Failed to find Auto Scaling Group for environment '${ENV_NAME}'.${NC}"
    exit 1
fi

echo -e "${GREEN}Found ASG: ${ASG_NAME}${NC}"

# ------------------------------------------------------------------------------
# 2. Retrieve Launch Template Details
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ [Step 2/5] Inspecting Launch Template...${NC}"
LT_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ASG_NAME}" --region "${AWS_REGION}" \
    --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId' --output text)

if [ -z "${LT_ID}" ] || [ "${LT_ID}" == "None" ]; then
    echo -e "${RED}❌ ASG is not configured with a Launch Template ID.${NC}"
    exit 1
fi

CURRENT_VERSION=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ASG_NAME}" --region "${AWS_REGION}" \
    --query 'AutoScalingGroups[0].LaunchTemplate.Version' --output text)

echo "Launch Template ID      : ${LT_ID}"
echo "Current Version in ASG  : ${CURRENT_VERSION}"

# ------------------------------------------------------------------------------
# 3. Create New Launch Template Version with Immutable Image Tag
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ [Step 3/5] Creating new Launch Template version with updated image tag...${NC}"

# Get current user_data from $Latest version
CURRENT_USER_DATA_B64=$(aws ec2 describe-launch-template-versions \
    --launch-template-id "${LT_ID}" \
    --versions '$Latest' \
    --region "${AWS_REGION}" \
    --query 'LaunchTemplateVersions[0].LaunchTemplateData.UserData' \
    --output text)

# Decode user data
DECODED_USER_DATA=$(echo "${CURRENT_USER_DATA_B64}" | base64 -d)

# Inject/update image_tag in user data
TAG_OVERRIDE_LINE="echo \"${IMAGE_TAG}\" > /opt/shopsphere/image_tag"
if echo "${DECODED_USER_DATA}" | grep -q "/opt/shopsphere/image_tag"; then
    MODIFIED_USER_DATA=$(echo "${DECODED_USER_DATA}" | sed "s|echo .* > /opt/shopsphere/image_tag|${TAG_OVERRIDE_LINE}|")
elif echo "${DECODED_USER_DATA}" | grep -q "^/opt/shopsphere/deploy.sh"; then
    MODIFIED_USER_DATA=$(echo "${DECODED_USER_DATA}" | sed "s|^/opt/shopsphere/deploy.sh.*$|${TAG_OVERRIDE_LINE}\n/opt/shopsphere/deploy.sh \"${IMAGE_TAG}\"|")
else
    echo -e "${YELLOW}⚠️ Detected legacy or non-container user data. Upgrading Launch Template to Stage 8 Docker Containerization...${NC}"
    DB_HOST=$(aws rds describe-db-instances --region "${AWS_REGION}" --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT_NAME}')].Endpoint.Address | [0]" --output text 2>/dev/null || echo "shopsphere-stage2-postgres.cy9mak0su1oj.us-east-1.rds.amazonaws.com")
    REDIS_HOST=$(aws elasticache describe-cache-clusters --region "${AWS_REGION}" --query "CacheClusters[?contains(CacheClusterId, '${PROJECT_NAME}')].CacheClusterId | [0]" --output text 2>/dev/null || echo "shopsphere-stage4-redis")
    REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --cache-cluster-id "${REDIS_HOST}" --show-cache-node-info --region "${AWS_REGION}" --query "CacheClusters[0].CacheNodes[0].Endpoint.Address" --output text 2>/dev/null || echo "shopsphere-stage4-redis.ekxmke.0001.use1.cache.amazonaws.com")
    SQS_URL=$(aws sqs list-queues --region "${AWS_REGION}" --queue-name-prefix "${PROJECT_NAME}" --query "QueueUrls[?contains(@, 'order-processing-queue') && !contains(@, 'dlq')] | [0]" --output text 2>/dev/null || echo "https://sqs.us-east-1.amazonaws.com/165772574557/shopsphere-stage5-order-processing-queue")
    ECR_URL=$(aws ecr describe-repositories --region "${AWS_REGION}" --query "repositories[?contains(repositoryName, '${PROJECT_NAME}')].repositoryUri | [0]" --output text 2>/dev/null || echo "165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage8-app")

    if [ -f "stage-8/terraform/scripts/user_data.sh.tpl" ]; then
        MODIFIED_USER_DATA=$(sed \
            -e "s|\${db_host}|${DB_HOST}|g" \
            -e "s|\${db_port}|5432|g" \
            -e "s|\${db_name}|shopspheredb|g" \
            -e "s|\${db_user}|shopsphere_user|g" \
            -e "s|\${db_password}|ShopSphere2026SecurePass!|g" \
            -e "s|\${aws_region}|${AWS_REGION}|g" \
            -e "s|\${redis_host}|${REDIS_ENDPOINT}|g" \
            -e "s|\${redis_port}|6379|g" \
            -e "s|\${sqs_queue_url}|${SQS_URL}|g" \
            -e "s|\${sqs_queue_name}|shopsphere-stage5-order-processing-queue|g" \
            -e "s|\${ecr_repository_url}|${ECR_URL}|g" \
            -e "s|\${app_repo_url}|https://github.com/vinodk11/shopsphere-aws-scaling.git|g" \
            -e "s|\${app_port}|8080|g" \
            -e "s|\$\${|\${|g" \
            stage-8/terraform/scripts/user_data.sh.tpl)
        MODIFIED_USER_DATA=$(echo "${MODIFIED_USER_DATA}" | sed "s|IMAGE_NAME=\"shopsphere-app:8.0.0\"|IMAGE_NAME=\"shopsphere-app:${IMAGE_TAG}\"|")
        MODIFIED_USER_DATA=$(echo "${MODIFIED_USER_DATA}" | sed "s|^/opt/shopsphere/deploy.sh.*$|${TAG_OVERRIDE_LINE}\n/opt/shopsphere/deploy.sh \"${IMAGE_TAG}\"|")
    fi
fi

NEW_USER_DATA_B64=$(echo "${MODIFIED_USER_DATA}" | base64 -w 0)

NEW_VERSION=$(aws ec2 create-launch-template-version \
    --launch-template-id "${LT_ID}" \
    --source-version '$Latest' \
    --version-description "Release-${IMAGE_TAG}" \
    --launch-template-data "{\"UserData\":\"${NEW_USER_DATA_B64}\"}" \
    --region "${AWS_REGION}" \
    --query 'LaunchTemplateVersion.VersionNumber' \
    --output text)

echo -e "${GREEN}Created new Launch Template version: ${NEW_VERSION}${NC}"

# Set default version on launch template
aws ec2 modify-launch-template \
    --launch-template-id "${LT_ID}" \
    --default-version "${NEW_VERSION}" \
    --region "${AWS_REGION}" >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# 4. Update ASG to Use $Latest Launch Template Version
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ [Step 4/5] Updating Auto Scaling Group to version \$Latest (${NEW_VERSION})...${NC}"
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${ASG_NAME}" \
    --launch-template "LaunchTemplateId=${LT_ID},Version=\$Latest" \
    --region "${AWS_REGION}"

echo -e "${GREEN}Auto Scaling Group updated successfully.${NC}"

# Deploy immediately to current running instances via SSM
if [ -f "stage-8/terraform/scripts/connect_asg_to_stage8.sh" ]; then
    echo -e "\n${BLUE}▶ Dispatched immediate Stage 8 container deployment via SSM to active ASG instances...${NC}"
    bash stage-8/terraform/scripts/connect_asg_to_stage8.sh "${IMAGE_TAG}" || true
fi

# ------------------------------------------------------------------------------
# 5. Initiate & Monitor ASG Rolling Instance Refresh
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}▶ [Step 5/5] Starting rolling Instance Refresh on ${ASG_NAME}...${NC}"
REFRESH_ID=$(aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "${ASG_NAME}" \
    --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 180}' \
    --region "${AWS_REGION}" \
    --query 'InstanceRefreshId' \
    --output text)

echo -e "${GREEN}Instance Refresh Started (ID: ${REFRESH_ID})${NC}"
echo "Rolling replacement configuration: MinHealthyPercentage=50%, InstanceWarmup=180s"
echo "Polling instance refresh status every ${POLL_INTERVAL}s (Timeout: ${MAX_WAIT_MINUTES}m)..."

START_TIME=$(date +%s)
TIMEOUT_SECONDS=$((MAX_WAIT_MINUTES * 60))

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
        echo -e "\n${RED}❌ Error: Instance Refresh timed out after ${MAX_WAIT_MINUTES} minutes.${NC}"
        aws autoscaling cancel-instance-refresh --auto-scaling-group-name "${ASG_NAME}" --region "${AWS_REGION}" || true
        exit 1
    fi

    REFRESH_DATA=$(aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "${ASG_NAME}" \
        --instance-refresh-ids "${REFRESH_ID}" \
        --region "${AWS_REGION}" \
        --query 'InstanceRefreshes[0]' \
        --output json)

    STATUS=$(echo "${REFRESH_DATA}" | grep -o '"Status": "[^"]*' | cut -d'"' -f4 || echo "Unknown")
    PERCENT=$(echo "${REFRESH_DATA}" | grep -o '"PercentageComplete": [0-9]*' | awk '{print $2}' || echo "0")
    INSTANCES_TO_UPDATE=$(echo "${REFRESH_DATA}" | grep -o '"InstancesToUpdate": [0-9]*' | awk '{print $2}' || echo "0")

    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    printf "[%02dm:%02ds] Status: %-15s | Progress: %3d%% | Remaining: %s instances\n" "${MINUTES}" "${SECONDS}" "${STATUS}" "${PERCENT:-0}" "${INSTANCES_TO_UPDATE:-0}"

    case "${STATUS}" in
        "Successful")
            echo -e "\n${GREEN}🎉 ASG Instance Refresh completed successfully!${NC}"
            echo "All instances are running immutable release: ${IMAGE_TAG}"
            CF_DIST_ID=$(aws cloudfront list-distributions --region "${AWS_REGION}" --query "DistributionList.Items[?contains(Comment, '${PROJECT_NAME}')].Id | [0]" --output text 2>/dev/null || true)
            if [ -n "${CF_DIST_ID:-}" ] && [ "${CF_DIST_ID}" != "None" ]; then
                echo "Invalidating CloudFront cache for distribution: ${CF_DIST_ID}..."
                aws cloudfront create-invalidation --distribution-id "${CF_DIST_ID}" --paths "/*" --region "${AWS_REGION}" >/dev/null 2>&1 || true
            fi
            exit 0
            ;;
        "Failed")
            STATUS_REASON=$(echo "${REFRESH_DATA}" | grep -o '"StatusReason": "[^"]*' | cut -d'"' -f4 || echo "Unknown reason")
            echo -e "\n${RED}❌ Instance Refresh FAILED! Reason: ${STATUS_REASON}${NC}"
            exit 1
            ;;
        "Cancelled")
            echo -e "\n${RED}❌ Instance Refresh was CANCELLED.${NC}"
            exit 1
            ;;
        "RollbackSuccessful"|"RollbackFailed")
            echo -e "\n${RED}❌ Instance Refresh triggered an automatic rollback (Status: ${STATUS}).${NC}"
            exit 1
            ;;
        *)
            sleep "${POLL_INTERVAL}"
            ;;
    esac
done
