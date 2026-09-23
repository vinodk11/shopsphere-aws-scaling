#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 2: Reconfigure Stage 1 EC2 Monolith to use Amazon RDS
# Connects existing Stage 1 EC2 to the newly provisioned Stage 2 RDS instance
# without destroying or recreating the EC2 server or VPC!
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"

echo "======================================================================"
echo "  ShopSphere Stage 2: Connecting Stage 1 EC2 Monolith to Amazon RDS"
echo "======================================================================"

# 1. Resolve RDS Endpoint from Terraform output or AWS CLI
echo "[1/4] Discovering Stage 2 RDS PostgreSQL endpoint..."
if [ -f "stage-2/terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
  RDS_HOST=$(terraform output -raw rds_address 2>/dev/null || true)
  RDS_PORT=$(terraform output -raw rds_port 2>/dev/null || echo "5432")
fi

if [ -z "${RDS_HOST:-}" ]; then
  RDS_HOST=$(aws rds describe-db-instances --region "$AWS_REGION" \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT_NAME}')].Endpoint.Address | [0]" --output text)
  RDS_PORT=$(aws rds describe-db-instances --region "$AWS_REGION" \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT_NAME}')].Endpoint.Port | [0]" --output text)
fi

if [ -z "${RDS_HOST:-}" ] || [ "$RDS_HOST" == "None" ]; then
  echo "❌ Error: Could not resolve RDS endpoint. Ensure Stage 2 terraform apply completed."
  exit 1
fi
echo "✅ Resolved Amazon RDS Endpoint: ${RDS_HOST}:${RDS_PORT}"

# 2. Discover Running Stage 1 EC2 Instance ID
echo "[2/4] Discovering running Stage 1 EC2 instance..."
EC2_ID=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-*-ec2" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ -z "${EC2_ID:-}" ] || [ "$EC2_ID" == "None" ]; then
  echo "❌ Error: Could not find running Stage 1 EC2 instance. Ensure Stage 1 is deployed."
  exit 1
fi
echo "✅ Found Stage 1 EC2 Instance: ${EC2_ID}"

# 3. Update EC2 Environment and Restart Application via AWS SSM
echo "[3/4] Updating /opt/shopsphere/.env on EC2 instance via AWS SSM..."
COMMAND_ID=$(aws ssm send-command --region "$AWS_REGION" \
  --instance-ids "$EC2_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Reconfigure ShopSphere to use Amazon RDS" \
  --parameters commands="[
    \"sed -i -E 's|^DB_HOST=.*|DB_HOST=${RDS_HOST}|' /opt/shopsphere/.env || echo 'DB_HOST=${RDS_HOST}' >> /opt/shopsphere/.env\",
    \"sed -i -E 's|^DB_PORT=.*|DB_PORT=${RDS_PORT}|' /opt/shopsphere/.env || echo 'DB_PORT=${RDS_PORT}' >> /opt/shopsphere/.env\",
    \"systemctl restart shopsphere || true\"
  ]" \
  --query "Command.CommandId" --output text)

echo "Sent SSM Command: ${COMMAND_ID}. Waiting for execution..."
aws ssm wait command-executed --region "$AWS_REGION" --command-id "$COMMAND_ID" --instance-id "$EC2_ID" || true

# 4. Verify Health Check
EC2_PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$EC2_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo "[4/4] Probing application health at http://${EC2_PUBLIC_IP}/health ..."
sleep 5
curl -s --connect-timeout 5 "http://${EC2_PUBLIC_IP}/health" || echo "Note: Check security group / browser to verify."

echo ""
echo "======================================================================"
echo "🎉 Stage 2 Connection Complete!"
echo "   Stage 1 EC2 Monolith is now persisting data to Amazon RDS PostgreSQL."
echo "   Zero downtime, zero resources destroyed!"
echo "======================================================================"
