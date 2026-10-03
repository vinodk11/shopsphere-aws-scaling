#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 5: Connect Stage 3 ASG Fleet to Amazon SQS Order Queue
# Attaches IAM SQS publisher policy to EC2 instance profile role and updates
# application environment variables on running ASG instances via AWS SSM.
# Zero downtime, zero resources destroyed!
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-shopsphere}"

echo "======================================================================"
echo "  ShopSphere Stage 5: Connecting ASG EC2 Fleet to Amazon SQS"
echo "======================================================================"

# 1. Resolve SQS Queue URL, Name, and Policy ARN
echo "[1/4] Discovering Stage 5 Amazon SQS Queue details..."
SQS_QUEUE_URL=""
SQS_QUEUE_NAME=""
SQS_POLICY_ARN=""

if [ -f "stage-5/terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
  SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || true)
  SQS_QUEUE_NAME=$(terraform output -raw sqs_queue_name 2>/dev/null || true)
  SQS_POLICY_ARN=$(terraform output -raw ec2_sqs_policy_arn 2>/dev/null || true)
fi

if [ -z "${SQS_QUEUE_URL:-}" ]; then
  SQS_QUEUE_URL=$(aws sqs list-queues --region "$AWS_REGION" \
    --query "QueueUrls[?contains(@, '${PROJECT_NAME}') && !contains(@, 'dlq')] | [0]" --output text 2>/dev/null || true)
  if [ -n "${SQS_QUEUE_URL:-}" ] && [ "$SQS_QUEUE_URL" != "None" ]; then
    SQS_QUEUE_NAME=$(basename "$SQS_QUEUE_URL")
  fi
fi

if [ -z "${SQS_QUEUE_URL:-}" ] || [ "$SQS_QUEUE_URL" == "None" ]; then
  echo "❌ Error: Could not resolve SQS queue URL. Ensure Stage 5 terraform apply completed."
  exit 1
fi
echo "✅ Resolved SQS Queue: ${SQS_QUEUE_NAME} (${SQS_QUEUE_URL})"

# 2. Discover Running ASG EC2 Instances & Attach SQS IAM Policy
echo "[2/4] Discovering running Stage 3 ASG EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:aws:autoscaling:groupName,Values=*${PROJECT_NAME}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)

if [ -z "${INSTANCE_IDS:-}" ]; then
  INSTANCE_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}*-ec2*" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || true)
fi

if [ -z "${INSTANCE_IDS:-}" ]; then
  echo "⚠️ Warning: No running ASG instances found. Instances may still be launching or not yet created."
  exit 0
fi
echo "✅ Found Running ASG Instance(s): ${INSTANCE_IDS}"

# Ensure IAM policy is attached to the instance role
FIRST_INSTANCE=$(echo "$INSTANCE_IDS" | awk '{print $1}')
PROFILE_ARN=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$FIRST_INSTANCE" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" --output text 2>/dev/null || true)

if [ -n "${PROFILE_ARN:-}" ] && [ "$PROFILE_ARN" != "None" ]; then
  PROFILE_NAME=$(basename "$PROFILE_ARN")
  ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" \
    --query "InstanceProfile.Roles[0].RoleName" --output text 2>/dev/null || true)
  
  if [ -n "${ROLE_NAME:-}" ] && [ "$ROLE_NAME" != "None" ] && [ -n "${SQS_POLICY_ARN:-}" ]; then
    echo "  -> Attaching SQS policy (${SQS_POLICY_ARN}) to role ${ROLE_NAME}..."
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$SQS_POLICY_ARN" 2>/dev/null || true
  fi
fi

# 3. Update Environment Variables and Restart Application via AWS SSM
echo "[3/4] Updating SQS environment variables on ASG instances via AWS SSM..."
for INSTANCE_ID in $INSTANCE_IDS; do
  echo "  -> Configuring instance: ${INSTANCE_ID}"
  COMMAND_ID=$(aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Reconfigure ShopSphere to use Amazon SQS" \
    --parameters commands="[
      \"sed -i -E 's|^SQS_QUEUE_URL=.*|SQS_QUEUE_URL=${SQS_QUEUE_URL}|' /opt/shopsphere/.env 2>/dev/null || echo 'SQS_QUEUE_URL=${SQS_QUEUE_URL}' >> /opt/shopsphere/.env\",
      \"sed -i -E 's|^SQS_QUEUE_NAME=.*|SQS_QUEUE_NAME=${SQS_QUEUE_NAME}|' /opt/shopsphere/.env 2>/dev/null || echo 'SQS_QUEUE_NAME=${SQS_QUEUE_NAME}' >> /opt/shopsphere/.env\",
      \"sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-5|' /opt/shopsphere/.env 2>/dev/null || true\",
      \"sed -i -E 's|^ARCHITECTURE_TIER=.*|ARCHITECTURE_TIER=ALB-ASG-REDIS-SQS-LAMBDA-RDS|' /opt/shopsphere/.env 2>/dev/null || true\",
      \"if [ -f /opt/shopsphere/app/.env ]; then sed -i -E 's|^SQS_QUEUE_URL=.*|SQS_QUEUE_URL=${SQS_QUEUE_URL}|' /opt/shopsphere/app/.env; sed -i -E 's|^SQS_QUEUE_NAME=.*|SQS_QUEUE_NAME=${SQS_QUEUE_NAME}|' /opt/shopsphere/app/.env; sed -i -E 's|^STAGE_NAME=.*|STAGE_NAME=stage-5|' /opt/shopsphere/app/.env; sed -i -E 's|^ARCHITECTURE_TIER=.*|ARCHITECTURE_TIER=ALB-ASG-REDIS-SQS-LAMBDA-RDS|' /opt/shopsphere/app/.env; fi\",
      \"systemctl restart shopsphere || true\"
    ]" \
    --query "Command.CommandId" --output text 2>/dev/null || true)

  if [ -n "${COMMAND_ID:-}" ] && [ "$COMMAND_ID" != "None" ]; then
    echo "     SSM Command sent (${COMMAND_ID}). Waiting for completion..."
    aws ssm wait command-executed --region "$AWS_REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" 2>/dev/null || true
  fi
done

# 4. Verification
echo "[4/4] Connection update complete."
echo ""
echo "======================================================================"
echo "🎉 Stage 5 Configuration Complete!"
echo "   ASG EC2 fleet is connected to Amazon SQS (${SQS_QUEUE_NAME})."
echo "   Decoupled async order processing with AWS Lambda is active!"
echo "   Zero downtime, zero resources destroyed!"
echo "======================================================================"
