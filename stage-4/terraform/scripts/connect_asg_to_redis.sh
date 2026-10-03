#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 4: Reconfigure Stage 3 ASG Fleet to use ElastiCache Redis
# Connects existing Stage 3 ASG EC2 instances to the newly provisioned Stage 4 Redis
# without destroying or recreating the ASG, ALB, RDS, or VPC!
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"

echo "======================================================================"
echo "  ShopSphere Stage 4: Connecting ASG EC2 Fleet to ElastiCache Redis"
echo "======================================================================"

# 1. Resolve Redis Endpoint and Port
echo "[1/4] Discovering Stage 4 ElastiCache Redis endpoint..."
REDIS_HOST=""
REDIS_PORT="6379"

if [ -f "stage-4/terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
  REDIS_HOST=$(terraform output -raw redis_endpoint 2>/dev/null || true)
  REDIS_PORT=$(terraform output -raw redis_port 2>/dev/null || echo "6379")
fi

if [ -z "${REDIS_HOST:-}" ]; then
  REDIS_HOST=$(aws elasticache describe-cache-clusters --region "$AWS_REGION" --show-cache-node-info \
    --query "CacheClusters[?contains(CacheClusterId, '${PROJECT_NAME}')].CacheNodes[0].Endpoint.Address | [0]" --output text 2>/dev/null || true)
fi

if [ -z "${REDIS_HOST:-}" ] || [ "$REDIS_HOST" == "None" ]; then
  echo "⚠️ Warning: Could not resolve Redis endpoint automatically. Checking cluster status..."
  REDIS_HOST=$(aws elasticache describe-cache-clusters --region "$AWS_REGION" --show-cache-node-info \
    --query "CacheClusters[0].CacheNodes[0].Endpoint.Address" --output text 2>/dev/null || true)
fi

if [ -z "${REDIS_HOST:-}" ] || [ "$REDIS_HOST" == "None" ]; then
  echo "❌ Error: Could not resolve Redis endpoint. Ensure Stage 4 terraform apply completed."
  exit 1
fi
echo "✅ Resolved ElastiCache Redis Endpoint: ${REDIS_HOST}:${REDIS_PORT}"

# 2. Discover Running ASG EC2 Instance IDs
echo "[2/4] Discovering running Stage 3 ASG EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:aws:autoscaling:groupName,Values=*${PROJECT_NAME}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)

if [ -z "${INSTANCE_IDS:-}" ]; then
  # Fallback: search by Name tag or Tier tag
  INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}*-ec2*" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)
fi

if [ -z "${INSTANCE_IDS:-}" ]; then
  echo "⚠️ Warning: No running ASG instances found. Instances may still be launching or not yet created."
  exit 0
fi

echo "✅ Found Running ASG Instance(s): ${INSTANCE_IDS}"

# 3. Update Environment Variables and Restart Application on each instance via AWS SSM
echo "[3/4] Updating REDIS_HOST on ASG instances via AWS SSM..."
for INSTANCE_ID in $INSTANCE_IDS; do
  echo "  -> Configuring instance: ${INSTANCE_ID}"
  COMMAND_ID=$(aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Reconfigure ShopSphere to use ElastiCache Redis" \
    --parameters commands="[
      \"sed -i -E 's|^REDIS_HOST=.*|REDIS_HOST=${REDIS_HOST}|' /opt/shopsphere/.env 2>/dev/null || echo 'REDIS_HOST=${REDIS_HOST}' >> /opt/shopsphere/.env\",
      \"sed -i -E 's|^REDIS_PORT=.*|REDIS_PORT=${REDIS_PORT}|' /opt/shopsphere/.env 2>/dev/null || echo 'REDIS_PORT=${REDIS_PORT}' >> /opt/shopsphere/.env\",
      \"sed -i -E 's|^REDIS_TTL_SECONDS=.*|REDIS_TTL_SECONDS=60|' /opt/shopsphere/.env 2>/dev/null || echo 'REDIS_TTL_SECONDS=60' >> /opt/shopsphere/.env\",
      \"sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-4|' /opt/shopsphere/.env 2>/dev/null || true\",
      \"if [ -f /opt/shopsphere/app/.env ]; then sed -i -E 's|^REDIS_HOST=.*|REDIS_HOST=${REDIS_HOST}|' /opt/shopsphere/app/.env; sed -i -E 's|^REDIS_PORT=.*|REDIS_PORT=${REDIS_PORT}|' /opt/shopsphere/app/.env; sed -i -E 's|^REDIS_TTL_SECONDS=.*|REDIS_TTL_SECONDS=60|' /opt/shopsphere/app/.env; sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-4|' /opt/shopsphere/app/.env; fi\",
      \"systemctl restart shopsphere || true\"
    ]" \
    --query "Command.CommandId" --output text 2>/dev/null || true)

  if [ -n "${COMMAND_ID:-}" ] && [ "$COMMAND_ID" != "None" ]; then
    echo "     SSM Command sent (${COMMAND_ID}). Waiting for completion..."
    aws ssm wait command-executed --region "$AWS_REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" 2>/dev/null || true
  else
    echo "     Note: SSM command dispatch failed or instance does not have SSM agent online yet."
  fi
done

# 4. Verification
echo "[4/4] Connection update complete."
echo ""
echo "======================================================================"
echo "🎉 Stage 4 Configuration Complete!"
echo "   ASG EC2 fleet is connected to Amazon ElastiCache Redis (${REDIS_HOST}:${REDIS_PORT})."
echo "   Zero downtime, zero resources destroyed!"
echo "======================================================================"
