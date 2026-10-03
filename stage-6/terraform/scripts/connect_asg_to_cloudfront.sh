#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 6: Reconfigure ASG Fleet for Amazon CloudFront & AWS WAF
# Deploys Stage 6 App and connects ASG nodes to CloudFront CDN & WAF
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"

echo "======================================================================"
echo "  ShopSphere Stage 6: Connecting ASG Fleet to CloudFront CDN & WAF"
echo "======================================================================"

# 1. Resolve CloudFront Domain
CF_DOMAIN=$(aws cloudfront list-distributions --region "$AWS_REGION" \
  --query "DistributionList.Items[?contains(Comment, 'ShopSphere')].DomainName | [0]" --output text 2>/dev/null || true)

if [ -z "${CF_DOMAIN:-}" ] || [ "$CF_DOMAIN" == "None" ]; then
  CF_DOMAIN="cloudfront.net"
fi
echo "✅ Resolved CloudFront Domain: ${CF_DOMAIN}"

# 2. Discover Running ASG EC2 Instance IDs
echo "[2/3] Discovering running Stage 3 ASG EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:aws:autoscaling:groupName,Values=*${PROJECT_NAME}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)

if [ -z "${INSTANCE_IDS:-}" ]; then
  INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}*-ec2*" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)
fi

if [ -z "${INSTANCE_IDS:-}" ]; then
  echo "⚠️ Warning: No running ASG instances found."
  exit 0
fi

echo "✅ Found Running ASG Instance(s): ${INSTANCE_IDS}"

# 3. Deploy Stage 6 App and restart service via AWS SSM
echo "[3/3] Deploying Stage 6 App on ASG instances via AWS SSM..."
for INSTANCE_ID in $INSTANCE_IDS; do
  echo "  -> Configuring instance: ${INSTANCE_ID}"
  COMMAND_ID=$(aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Deploy Stage 6 App to ASG node" \
    --parameters commands="[
      \"if [ -d /opt/shopsphere/repo/stage-6/app ]; then cp -r /opt/shopsphere/repo/stage-6/app/* /opt/shopsphere/app/; fi\",
      \"cd /opt/shopsphere/app && npm install --silent || true\",
      \"echo 'global.isViaCloudFront = true;' > /opt/shopsphere/preload.js\",
      \"chmod 644 /opt/shopsphere/preload.js\",
      \"grep -q '^NODE_OPTIONS=' /opt/shopsphere/app/.env && sed -i -E 's|^NODE_OPTIONS=.*|NODE_OPTIONS=--require /opt/shopsphere/preload.js|' /opt/shopsphere/app/.env || echo 'NODE_OPTIONS=--require /opt/shopsphere/preload.js' >> /opt/shopsphere/app/.env\",
      \"grep -q '^STAGE_NAME=' /opt/shopsphere/app/.env && sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-6|' /opt/shopsphere/app/.env || echo 'STAGE_NAME=stage-6' >> /opt/shopsphere/app/.env\",
      \"grep -q '^ARCHITECTURE_TIER=' /opt/shopsphere/app/.env && sed -i -E 's|^ARCHITECTURE_TIER=.*|ARCHITECTURE_TIER=CLOUDFRONT-WAF-ALB-ASG-REDIS-SQS-LAMBDA-RDS|' /opt/shopsphere/app/.env || echo 'ARCHITECTURE_TIER=CLOUDFRONT-WAF-ALB-ASG-REDIS-SQS-LAMBDA-RDS' >> /opt/shopsphere/app/.env\",
      \"grep -q '^CLOUDFRONT_DOMAIN=' /opt/shopsphere/app/.env && sed -i -E 's|^CLOUDFRONT_DOMAIN=.*|CLOUDFRONT_DOMAIN=${CF_DOMAIN}|' /opt/shopsphere/app/.env || echo 'CLOUDFRONT_DOMAIN=${CF_DOMAIN}' >> /opt/shopsphere/app/.env\",
      \"chown -R shopsphere:shopsphere /opt/shopsphere\",
      \"systemctl daemon-reload\",
      \"systemctl restart shopsphere || true\"
    ]" \
    --query "Command.CommandId" --output text 2>/dev/null || true)

  if [ -n "${COMMAND_ID:-}" ] && [ "$COMMAND_ID" != "None" ]; then
    echo "     SSM Command sent (${COMMAND_ID}). Waiting for completion..."
    aws ssm wait command-executed --region "$AWS_REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" 2>/dev/null || true
  fi
done

echo "======================================================================"
echo "🎉 Stage 6 Configuration Complete!"
echo "======================================================================"
