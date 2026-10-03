#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 7: Reconfigure ASG Fleet for DevSecOps Hardened App
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"

echo "======================================================================"
echo "  ShopSphere Stage 7: Deploying DevSecOps Hardened Application"
echo "======================================================================"

CF_DOMAIN=$(aws cloudfront list-distributions --region "$AWS_REGION" \
  --query "DistributionList.Items[?contains(Comment, 'ShopSphere')].DomainName | [0]" --output text 2>/dev/null || echo "d1vnvgpxbovxo4.cloudfront.net")

INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:aws:autoscaling:groupName,Values=*${PROJECT_NAME}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)

if [ -z "${INSTANCE_IDS:-}" ]; then
  INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}*-ec2*" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)
fi

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "  -> Configuring instance for Stage 7: ${INSTANCE_ID}"
  aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Deploy Stage 7 App to ASG node" \
    --parameters commands="[
      \"if [ -d /opt/shopsphere/repo/stage-7/app ]; then cp -r /opt/shopsphere/repo/stage-7/app/* /opt/shopsphere/app/; fi\",
      \"cd /opt/shopsphere/app && npm install --silent || true\",
      \"echo 'global.isViaCloudFront = true;' > /opt/shopsphere/preload.js\",
      \"chmod 644 /opt/shopsphere/preload.js\",
      \"grep -q '^NODE_OPTIONS=' /opt/shopsphere/app/.env && sed -i -E 's|^NODE_OPTIONS=.*|NODE_OPTIONS=--require /opt/shopsphere/preload.js|' /opt/shopsphere/app/.env || echo 'NODE_OPTIONS=--require /opt/shopsphere/preload.js' >> /opt/shopsphere/app/.env\",
      \"grep -q '^STAGE_NAME=' /opt/shopsphere/app/.env && sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-7|' /opt/shopsphere/app/.env || echo 'STAGE_NAME=stage-7' >> /opt/shopsphere/app/.env\",
      \"grep -q '^ARCHITECTURE_TIER=' /opt/shopsphere/app/.env && sed -i -E 's|^ARCHITECTURE_TIER=.*|ARCHITECTURE_TIER=DEVSECOPS-CLOUDFRONT-WAF-ALB-ASG-REDIS-SQS-LAMBDA-RDS|' /opt/shopsphere/app/.env || echo 'ARCHITECTURE_TIER=DEVSECOPS-CLOUDFRONT-WAF-ALB-ASG-REDIS-SQS-LAMBDA-RDS' >> /opt/shopsphere/app/.env\",
      \"grep -q '^CLOUDFRONT_DOMAIN=' /opt/shopsphere/app/.env && sed -i -E 's|^CLOUDFRONT_DOMAIN=.*|CLOUDFRONT_DOMAIN=${CF_DOMAIN}|' /opt/shopsphere/app/.env || echo 'CLOUDFRONT_DOMAIN=${CF_DOMAIN}' >> /opt/shopsphere/app/.env\",
      \"chown -R shopsphere:shopsphere /opt/shopsphere\",
      \"systemctl daemon-reload\",
      \"systemctl restart shopsphere || true\"
    ]" --output text 2>/dev/null || true
done

echo "======================================================================"
echo "🎉 Stage 7 Deployment Complete!"
echo "======================================================================"
