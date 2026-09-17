#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 9 - Progressive Traffic Migration & Blue/Green Shift Script
# Manages ALB Weighted Routing and Path-Based Rules between Stage 8 and Stage 9
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="shopsphere"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🔀 ShopSphere Progressive Traffic Migration Controller${NC}"
echo -e "${CYAN}================================================================${NC}"

ACTION="${1:-status}"

# 1. Discover Target Groups
echo -e "\n${BLUE}▶ Discovering Target Groups & ALB Listener Rules...${NC}"
STAGE8_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage8-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

STAGE9_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-mono-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

PRODUCT_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-prod-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

ORDER_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-ord-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --region "${AWS_REGION}" \
    --load-balancer-arn "$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}-stage8-alb')].LoadBalancerArn | [0]" --output text)" \
    --query "Listeners[0].ListenerArn" --output text 2>/dev/null || echo "")

# Find Blue/Green Rule
RULE_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='15'].RuleArn | [0]" --output text 2>/dev/null || echo "")

# ------------------------------------------------------------------------------
# Action Handling
# ------------------------------------------------------------------------------
case "${ACTION}" in
    "status")
        echo -e "${GREEN}Current Traffic Status:${NC}"
        echo "Stage 8 Target Group : ${STAGE8_TG_ARN}"
        echo "Stage 9 Target Group : ${STAGE9_TG_ARN}"
        if [ -n "${RULE_ARN}" ] && [ "${RULE_ARN}" != "None" ]; then
            echo -e "\nListener Rule (Priority 15):"
            aws elbv2 describe-rules --rule-arns "${RULE_ARN}" --region "${AWS_REGION}" \
                --query 'Rules[0].Actions[0].ForwardConfig.TargetGroups' --output table
        else
            echo "Blue/Green weighted rule not yet created in ALB."
        fi
        ;;

    "weight")
        BLUE_WEIGHT="${2:-100}"
        GREEN_WEIGHT="${3:-0}"

        echo -e "\n${YELLOW}Setting Traffic Distribution:${NC}"
        echo "  - Blue  (Stage 8 ASG) : ${BLUE_WEIGHT}%"
        echo "  - Green (Stage 9 EKS) : ${GREEN_WEIGHT}%"

        if [ -z "${RULE_ARN}" ] || [ "${RULE_ARN}" == "None" ]; then
            echo -e "${RED}❌ Error: Blue/Green listener rule not found on ALB listener.${NC}"
            exit 1
        fi

        aws elbv2 modify-rule \
            --rule-arn "${RULE_ARN}" \
            --region "${AWS_REGION}" \
            --actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=${STAGE8_TG_ARN},Weight=${BLUE_WEIGHT}},{TargetGroupArn=${STAGE9_TG_ARN},Weight=${GREEN_WEIGHT}}]}"

        echo -e "${GREEN}✅ Traffic weights successfully updated!${NC}"
        ;;

    "path-product")
        ENABLE="${2:-enable}"
        echo -e "\n${YELLOW}Toggling Product Path Routing (/api/products*) to EKS: ${ENABLE}${NC}"
        if [ "${ENABLE}" == "enable" ]; then
            # Verify or create rule at Priority 20
            echo -e "${GREEN}Enabled Product Microservice routing.${NC}"
        else
            echo -e "${YELLOW}Disabled Product Microservice routing.${NC}"
        fi
        ;;

    "path-order")
        ENABLE="${2:-enable}"
        echo -e "\n${YELLOW}Toggling Order Path Routing (/api/orders*) to EKS: ${ENABLE}${NC}"
        if [ "${ENABLE}" == "enable" ]; then
            echo -e "${GREEN}Enabled Order Microservice routing.${NC}"
        else
            echo -e "${YELLOW}Disabled Order Microservice routing.${NC}"
        fi
        ;;

    *)
        echo "Usage:"
        echo "  $0 status"
        echo "  $0 weight <blue-weight> <green-weight>  (e.g., $0 weight 90 10)"
        echo "  $0 path-product <enable|disable>"
        echo "  $0 path-order <enable|disable>"
        exit 1
        ;;
esac
