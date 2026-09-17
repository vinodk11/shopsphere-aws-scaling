#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 9 - Progressive Traffic Migration & Blue/Green Shift Script
# Manages ALB Weighted Routing and Path-Based Rules between Stage 8 and Stage 9
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="shopsphere"
CF_SECRET_TOKEN="ShopSphereEdgeSecretToken2026Verify"

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

# Discover Rules
RULE_10_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='10'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_15_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='15'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_PROD_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='5'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_ORD_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='6'].RuleArn | [0]" --output text 2>/dev/null || echo "")

# ------------------------------------------------------------------------------
# Action Handling
# ------------------------------------------------------------------------------
case "${ACTION}" in
    "status")
        echo -e "${GREEN}Target Groups:${NC}"
        echo "  Stage 8 Monolith ASG   : ${STAGE8_TG_ARN}"
        echo "  Stage 9 EKS Monolith   : ${STAGE9_TG_ARN}"
        echo "  Stage 9 EKS Product    : ${PRODUCT_TG_ARN}"
        echo "  Stage 9 EKS Order      : ${ORDER_TG_ARN}"

        echo -e "\n${GREEN}Active Listener Rules:${NC}"
        aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
            --query "Rules[].{Priority:Priority,Actions:Actions[0].Type,ForwardConfig:Actions[0].ForwardConfig.TargetGroups[].{TG:TargetGroupArn,Weight:Weight}}" --output json
        ;;

    "weight")
        BLUE_WEIGHT="${2:-100}"
        GREEN_WEIGHT="${3:-0}"

        echo -e "\n${YELLOW}Setting Traffic Distribution:${NC}"
        echo "  - Blue  (Stage 8 ASG) : ${BLUE_WEIGHT}%"
        echo "  - Green (Stage 9 EKS) : ${GREEN_WEIGHT}%"

        # Modify Rule 10 (Primary CloudFront Edge Verified Rule)
        if [ -n "${RULE_10_ARN}" ] && [ "${RULE_10_ARN}" != "None" ]; then
            echo "Updating Primary CloudFront Rule (Priority 10)..."
            aws elbv2 modify-rule \
                --rule-arn "${RULE_10_ARN}" \
                --region "${AWS_REGION}" \
                --actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=${STAGE8_TG_ARN},Weight=${BLUE_WEIGHT}},{TargetGroupArn=${STAGE9_TG_ARN},Weight=${GREEN_WEIGHT}}]}"
        fi

        # Modify Rule 15 if present
        if [ -n "${RULE_15_ARN}" ] && [ "${RULE_15_ARN}" != "None" ]; then
            echo "Updating General Rule (Priority 15)..."
            aws elbv2 modify-rule \
                --rule-arn "${RULE_15_ARN}" \
                --region "${AWS_REGION}" \
                --actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=${STAGE8_TG_ARN},Weight=${BLUE_WEIGHT}},{TargetGroupArn=${STAGE9_TG_ARN},Weight=${GREEN_WEIGHT}}]}"
        fi

        echo -e "${GREEN}✅ Traffic weights successfully updated!${NC}"
        ;;

    "path-product")
        ENABLE="${2:-enable}"
        echo -e "\n${YELLOW}Toggling Product Path Routing (/api/products*) to EKS: ${ENABLE}${NC}"
        if [ "${ENABLE}" == "enable" ]; then
            if [ -n "${RULE_PROD_ARN}" ] && [ "${RULE_PROD_ARN}" != "None" ]; then
                aws elbv2 modify-rule \
                    --rule-arn "${RULE_PROD_ARN}" \
                    --region "${AWS_REGION}" \
                    --actions "Type=forward,TargetGroupArn=${PRODUCT_TG_ARN}"
            else
                aws elbv2 create-rule \
                    --listener-arn "${ALB_LISTENER_ARN}" \
                    --priority 5 \
                    --conditions "[{\"Field\":\"path-pattern\",\"PathPatternConfig\":{\"Values\":[\"/api/products\",\"/api/products/*\"]}},{\"Field\":\"http-header\",\"HttpHeaderConfig\":{\"HttpHeaderName\":\"X-Origin-Verify\",\"Values\":[\"${CF_SECRET_TOKEN}\"]}}]" \
                    --actions "Type=forward,TargetGroupArn=${PRODUCT_TG_ARN}" \
                    --region "${AWS_REGION}"
            fi
            echo -e "${GREEN}✅ Enabled Product Microservice routing (Priority 5).${NC}"
        else
            if [ -n "${RULE_PROD_ARN}" ] && [ "${RULE_PROD_ARN}" != "None" ]; then
                aws elbv2 delete-rule --rule-arn "${RULE_PROD_ARN}" --region "${AWS_REGION}"
            fi
            echo -e "${YELLOW}Disabled Product Microservice routing.${NC}"
        fi
        ;;

    "path-order")
        ENABLE="${2:-enable}"
        echo -e "\n${YELLOW}Toggling Order Path Routing (/api/orders*) to EKS: ${ENABLE}${NC}"
        if [ "${ENABLE}" == "enable" ]; then
            if [ -n "${RULE_ORD_ARN}" ] && [ "${RULE_ORD_ARN}" != "None" ]; then
                aws elbv2 modify-rule \
                    --rule-arn "${RULE_ORD_ARN}" \
                    --region "${AWS_REGION}" \
                    --actions "Type=forward,TargetGroupArn=${ORDER_TG_ARN}"
            else
                aws elbv2 create-rule \
                    --listener-arn "${ALB_LISTENER_ARN}" \
                    --priority 6 \
                    --conditions "[{\"Field\":\"path-pattern\",\"PathPatternConfig\":{\"Values\":[\"/api/orders\",\"/api/orders/*\"]}},{\"Field\":\"http-header\",\"HttpHeaderConfig\":{\"HttpHeaderName\":\"X-Origin-Verify\",\"Values\":[\"${CF_SECRET_TOKEN}\"]}}]" \
                    --actions "Type=forward,TargetGroupArn=${ORDER_TG_ARN}" \
                    --region "${AWS_REGION}"
            fi
            echo -e "${GREEN}✅ Enabled Order Microservice routing (Priority 6).${NC}"
        else
            if [ -n "${RULE_ORD_ARN}" ] && [ "${RULE_ORD_ARN}" != "None" ]; then
                aws elbv2 delete-rule --rule-arn "${RULE_ORD_ARN}" --region "${AWS_REGION}"
            fi
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
