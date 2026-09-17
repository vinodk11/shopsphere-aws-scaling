#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 9 - Emergency Rollback Script
# Instantly reverts all traffic back to 100% Blue (Stage 8 EC2 ASG Monolith)
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="shopsphere"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}================================================================${NC}"
echo -e "${RED}🚨 EMERGENCY ROLLBACK: Reverting Traffic to Stage 8 Monolith${NC}"
echo -e "${RED}================================================================${NC}"

# 1. Discover Resources
echo -e "\n${YELLOW}▶ Locating Stage 8 Target Group & ALB Listener...${NC}"
STAGE8_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage8-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

STAGE9_TG_ARN=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_NAME}-stage9-eks-mono-tg')].TargetGroupArn | [0]" --output text 2>/dev/null || echo "")

ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --region "${AWS_REGION}" \
    --load-balancer-arn "$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}-stage8-alb')].LoadBalancerArn | [0]" --output text)" \
    --query "Listeners[0].ListenerArn" --output text 2>/dev/null || echo "")

RULE_10_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='10'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_15_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='15'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_PROD_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='5'].RuleArn | [0]" --output text 2>/dev/null || echo "")

RULE_ORD_ARN=$(aws elbv2 describe-rules --listener-arn "${ALB_LISTENER_ARN}" --region "${AWS_REGION}" \
    --query "Rules[?Priority=='6'].RuleArn | [0]" --output text 2>/dev/null || echo "")

if [ -z "${STAGE8_TG_ARN}" ] || [ "${STAGE8_TG_ARN}" == "None" ]; then
    echo -e "${RED}❌ Fatal: Stage 8 Target Group not found! Cannot execute automated rollback.${NC}"
    exit 1
fi

# 2. Reset Primary Weighted Rule (Priority 10): 100% Blue, 0% Green
if [ -n "${RULE_10_ARN}" ] && [ "${RULE_10_ARN}" != "None" ]; then
    echo -e "\n${YELLOW}▶ Resetting Primary ALB Listener Rule (Priority 10) to 100% Blue / 0% Green...${NC}"
    aws elbv2 modify-rule \
        --rule-arn "${RULE_10_ARN}" \
        --region "${AWS_REGION}" \
        --actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=${STAGE8_TG_ARN},Weight=100},{TargetGroupArn=${STAGE9_TG_ARN},Weight=0}]}"
    echo -e "${GREEN}✅ Primary CloudFront rule reset to 100% Stage 8.${NC}"
fi

# Reset Rule 15 if present
if [ -n "${RULE_15_ARN}" ] && [ "${RULE_15_ARN}" != "None" ]; then
    echo -e "\n${YELLOW}▶ Resetting ALB Listener Rule (Priority 15) to 100% Blue / 0% Green...${NC}"
    aws elbv2 modify-rule \
        --rule-arn "${RULE_15_ARN}" \
        --region "${AWS_REGION}" \
        --actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=${STAGE8_TG_ARN},Weight=100},{TargetGroupArn=${STAGE9_TG_ARN},Weight=0}]}"
    echo -e "${GREEN}✅ Priority 15 rule reset to 100% Stage 8.${NC}"
fi

# 3. Disable path rules if any were active
if [ -n "${RULE_PROD_ARN}" ] && [ "${RULE_PROD_ARN}" != "None" ]; then
    echo -e "\n${YELLOW}▶ Removing /api/products* microservice rule (Priority 5)...${NC}"
    aws elbv2 delete-rule --rule-arn "${RULE_PROD_ARN}" --region "${AWS_REGION}"
    echo -e "${GREEN}✅ Product path routed back to Stage 8 Monolith.${NC}"
fi

if [ -n "${RULE_ORD_ARN}" ] && [ "${RULE_ORD_ARN}" != "None" ]; then
    echo -e "\n${YELLOW}▶ Removing /api/orders* microservice rule (Priority 6)...${NC}"
    aws elbv2 delete-rule --rule-arn "${RULE_ORD_ARN}" --region "${AWS_REGION}"
    echo -e "${GREEN}✅ Order path routed back to Stage 8 Monolith.${NC}"
fi

# 4. Verify Stage 8 Target Group Health
echo -e "\n${YELLOW}▶ Verifying Stage 8 Target Group Health...${NC}"
aws elbv2 describe-target-health --target-group-arn "${STAGE8_TG_ARN}" --region "${AWS_REGION}" \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}' --output table

echo -e "\n${GREEN}🎉 ROLLBACK COMPLETE: 100% of traffic is safely served by Stage 8 Monolith.${NC}"
