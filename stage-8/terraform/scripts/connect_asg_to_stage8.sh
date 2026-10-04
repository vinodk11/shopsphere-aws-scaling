#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 8: Reconfigure ASG Fleet for Docker Containerized App
# Deploys Stage 8 Docker container image from Amazon ECR to ASG EC2 instances
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"
IMAGE_TAG="${1:-8.0.0}"

echo "======================================================================"
echo "  ShopSphere Stage 8: Deploying Docker Containerized Application"
echo "  Target Image Tag: ${IMAGE_TAG}"
echo "======================================================================"

CF_DOMAIN=$(aws cloudfront list-distributions --region "$AWS_REGION" \
  --query "DistributionList.Items[?contains(Comment, 'ShopSphere')].DomainName | [0]" --output text 2>/dev/null || echo "d2kl5ria2wure0.cloudfront.net")

ECR_URI=$(aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?contains(repositoryName, '${PROJECT_NAME}')].repositoryUri | [0]" --output text 2>/dev/null || echo "165772574557.dkr.ecr.us-east-1.amazonaws.com/shopsphere-stage8-app")

INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:aws:autoscaling:groupName,Values=*${PROJECT_NAME}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)

if [ -z "${INSTANCE_IDS:-}" ]; then
  INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}*-ec2*" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)
fi

echo "Discovered ASG Instances: ${INSTANCE_IDS}"
echo "CloudFront Domain: ${CF_DOMAIN}"
echo "Amazon ECR URI   : ${ECR_URI}"

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "  -> Configuring instance for Stage 8 Docker container: ${INSTANCE_ID}"
  aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Deploy Stage 8 Container App to ASG node" \
    --parameters commands="[
      \"export HOME=/root\",
      \"dnf install -y docker git postgresql15 nginx amazon-ssm-agent || true\",
      \"systemctl enable --now docker\",
      \"git config --global --add safe.directory '*' || true\",
      \"if [ ! -d /opt/shopsphere/repo ]; then git clone https://github.com/vinodk11/shopsphere-aws-scaling.git /opt/shopsphere/repo; else cd /opt/shopsphere/repo && git pull origin main || true; fi\",
      \"mkdir -p /opt/shopsphere/app\",
      \"if [ -d /opt/shopsphere/repo/stage-8/app ]; then cp -r /opt/shopsphere/repo/stage-8/app/* /opt/shopsphere/app/; fi\",
      \"cat > /opt/shopsphere/app/.env << 'ENV_EOF'
PORT=8080
NODE_ENV=production
AWS_REGION=us-east-1
DB_HOST=shopsphere-stage2-postgres.cy9mak0su1oj.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=shopspheredb
DB_USER=shopsphere_user
DB_PASSWORD=ShopSphere2026SecurePass!
DB_SSL=true
PGSSLMODE=no-verify
REDIS_HOST=shopsphere-stage4-redis.ekxmke.0001.use1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_TTL_SECONDS=60
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/165772574557/shopsphere-stage5-order-processing-queue
SQS_QUEUE_NAME=shopsphere-stage5-order-processing-queue
STAGE_NAME=stage-8
CLOUDFRONT_DOMAIN=${CF_DOMAIN}
DOCKER_CONTAINER=true
ARCHITECTURE_TIER=CONTAINER-DOCKER-ECR-ASG-CLOUDFRONT-WAF-ALB-REDIS-SQS-LAMBDA-RDS
ECR_REPOSITORY_URL=${ECR_URI}
IMAGE_TAG=${IMAGE_TAG}
ENV_EOF\",
      \"chmod 600 /opt/shopsphere/app/.env\",
      \"systemctl stop shopsphere || true\",
      \"systemctl disable shopsphere || true\",
      \"aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI%%/*} || true\",
      \"if ! docker pull ${ECR_URI}:${IMAGE_TAG}; then docker pull ${ECR_URI}:latest || docker pull ${ECR_URI}:8.0.0 || (docker build -t shopsphere-app:${IMAGE_TAG} /opt/shopsphere/repo/stage-8/app && docker tag shopsphere-app:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}); fi\",
      \"TARGET_IMG=\$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '(${IMAGE_TAG}|8.0.0|latest)' | head -n1 || echo '${ECR_URI}:8.0.0')\",
      \"docker rm -f shopsphere-app-prod 2>/dev/null || true\",
      \"docker run -d --name shopsphere-app-prod --restart always -p 127.0.0.1:8080:8080 --env-file /opt/shopsphere/app/.env \${TARGET_IMG}\",
      \"systemctl reload nginx || systemctl restart nginx\",
      \"sleep 3\",
      \"curl -s http://127.0.0.1:8080/health || true\"
    ]" --output text 2>/dev/null || true
done

echo "======================================================================"
echo "🎉 Stage 8 Docker Container Deployment Dispatched to ASG Fleet!"
echo "======================================================================"
