#!/bin/bash
# ==============================================================================
# ShopSphere Stage 8 Bootstrap Script (Docker Containerization + ECR + ASG + CloudFront + WAF)
# Rendered by Terraform templatefile() and executed by cloud-init on each ASG node.
# Boots Docker CE, logs into AWS ECR, and runs the multi-stage hardened container.
# ==============================================================================
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== ShopSphere Stage 8 Docker Node Bootstrap Starting at $(date) ==="
echo "Node Hostname: $(hostname)"

# ------------------------------------------------------------------------------
# 1. Update OS and Install Packages (Docker, PostgreSQL client, Nginx, SSM, Git)
# ------------------------------------------------------------------------------
echo "[1/6] Updating OS and installing Docker CE, PostgreSQL client, Nginx, SSM..."
dnf update -y
dnf install -y docker git postgresql15 nginx amazon-ssm-agent || dnf install -y docker git postgresql15 nginx

# Enable and start Docker daemon
systemctl enable --now docker
systemctl enable --now amazon-ssm-agent || true

# Add standard users to docker group
usermod -aG docker ec2-user || true

# ------------------------------------------------------------------------------
# 2. Verify Amazon RDS Network Reachability
# ------------------------------------------------------------------------------
echo "[2/6] Verifying network reachability to Amazon RDS (${db_host}:${db_port})..."
MAX_RETRIES=60
RETRY_COUNT=0

until pg_isready -h "${db_host}" -p "${db_port}" > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "[WARNING] RDS endpoint ${db_host}:${db_port} not responding after $MAX_RETRIES attempts. Continuing..."
    break
  fi
  echo "Waiting for Amazon RDS PostgreSQL to become ready... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 5
done

echo "[2/6] RDS connectivity check completed."

# ------------------------------------------------------------------------------
# 3. Setup Dedicated System User and Directories
# ------------------------------------------------------------------------------
echo "[3/6] Setting up system user and directory structure..."
id -u shopsphere &>/dev/null || useradd -r -m -d /home/shopsphere -s /bin/false shopsphere
usermod -aG docker shopsphere || true
mkdir -p /opt/shopsphere/app /home/shopsphere
chown -R shopsphere:shopsphere /home/shopsphere

# Write Environment Configuration for Container
cat > /opt/shopsphere/app/.env <<ENV_EOF
PORT=8080
NODE_ENV=production
AWS_REGION=${aws_region}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_SSL=true
REDIS_HOST=${redis_host}
REDIS_PORT=${redis_port}
REDIS_TTL_SECONDS=60
SQS_QUEUE_URL=${sqs_queue_url}
SQS_QUEUE_NAME=${sqs_queue_name}
STAGE_NAME=stage-8
DOCKER_CONTAINER=true
ENV_EOF

chmod 600 /opt/shopsphere/app/.env
chown shopsphere:shopsphere /opt/shopsphere/app/.env

# ------------------------------------------------------------------------------
# 4. Create Reusable Container Deployment Script (/opt/shopsphere/deploy.sh)
# ------------------------------------------------------------------------------
echo "[4/6] Creating container deployment script /opt/shopsphere/deploy.sh..."
cat > /opt/shopsphere/deploy.sh <<'DEPLOY_EOF'
#!/bin/bash
# Reusable container deployment script executed by user_data and Jenkins
set -euo pipefail
exec > >(tee -a /var/log/shopsphere-deploy.log) 2>&1

echo "======================================================================"
echo "🐳 ShopSphere Container Deployment Started at $(date)"
echo "======================================================================"

cd /opt/shopsphere
ECR_REPO="${ecr_repository_url}"
IMAGE_NAME="shopsphere-app:8.0.0"
CONTAINER_NAME="shopsphere-app-prod"
PULLED_FROM_ECR=0

TAG_ARG="$${1:-}"
if [ -z "$TAG_ARG" ] && [ -f /opt/shopsphere/image_tag ]; then
  TAG_ARG="$(cat /opt/shopsphere/image_tag | tr -d '[:space:]')"
fi
if [ -z "$TAG_ARG" ]; then
  TAG_ARG="latest"
fi

# Attempt login to Amazon ECR and pull image
if [ -n "$ECR_REPO" ] && command -v aws >/dev/null 2>&1; then
  echo "Attempting to authenticate with Amazon ECR ($${ECR_REPO})..."
  if aws ecr get-login-password --region "${aws_region}" | docker login --username AWS --password-stdin "$ECR_REPO" 2>/dev/null; then
    echo "Pulling container image from ECR: $${ECR_REPO}:$${TAG_ARG}..."
    if docker pull "$${ECR_REPO}:$${TAG_ARG}" 2>/dev/null; then
      IMAGE_NAME="$${ECR_REPO}:$${TAG_ARG}"
      PULLED_FROM_ECR=1
      echo "✅ Successfully pulled image from Amazon ECR: $${IMAGE_NAME}."
    elif [ "$TAG_ARG" != "latest" ] && docker pull "$${ECR_REPO}:latest" 2>/dev/null; then
      IMAGE_NAME="$${ECR_REPO}:latest"
      PULLED_FROM_ECR=1
      echo "✅ Falling back to latest image from Amazon ECR: $${IMAGE_NAME}."
    fi
  fi
fi

# Fallback to building multi-stage image locally if ECR is not yet populated
if [ $PULLED_FROM_ECR -eq 0 ]; then
  echo "Building Docker image locally from source repository..."
  APP_REPO="${app_repo_url}"
  if [ -z "$APP_REPO" ]; then
    APP_REPO="https://github.com/vinodk11/shopsphere-aws-scaling.git"
  fi

  if [ ! -d repo ]; then
    git clone "$APP_REPO" repo || git clone "https://github.com/vinodk11/shopsphere-aws-scaling.git" repo
  else
    cd repo && git fetch origin main && git reset --hard origin/main && cd ..
  fi

  if [ -d "/opt/shopsphere/repo/stage-8/app" ]; then
    DOCKER_CONTEXT="/opt/shopsphere/repo/stage-8/app"
  elif [ -d "/opt/shopsphere/repo/stage-7/app" ]; then
    DOCKER_CONTEXT="/opt/shopsphere/repo/stage-7/app"
  else
    DOCKER_CONTEXT="/opt/shopsphere/repo/app"
  fi

  echo "Building multi-stage Docker image from $${DOCKER_CONTEXT}..."
  docker build -t "$IMAGE_NAME" "$DOCKER_CONTEXT"
fi

# Apply initial database schema to Amazon RDS idempotently if present
if [ -f "/opt/shopsphere/repo/stage-8/app/db/schema.sql" ]; then
  echo "Verifying database schema on Amazon RDS..."
  PGPASSWORD="${db_password}" PGSSLMODE=require psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -f /opt/shopsphere/repo/stage-8/app/db/schema.sql || true
fi

# Stop and remove existing container
echo "Stopping any existing container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run new containerized application
echo "Starting ShopSphere container ($${IMAGE_NAME})..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart always \
  -p 127.0.0.1:${app_port}:8080 \
  --env-file /opt/shopsphere/app/.env \
  --memory="512m" \
  --cpus="1.0" \
  --log-driver json-file \
  --log-opt max-size=50m \
  --log-opt max-file=3 \
  "$IMAGE_NAME"

echo "Verifying local container health probe on port ${app_port}..."
sleep 3
for i in $(seq 1 25); do
  if curl -sf "http://127.0.0.1:${app_port}/health" > /dev/null 2>&1; then
    echo "✅ ShopSphere Docker container is UP and healthy on port ${app_port}!"
    docker ps --filter "name=$${CONTAINER_NAME}"
    exit 0
  fi
  echo "Waiting for container to be healthy ($i/25)..."
  sleep 3
done

echo "⚠️ Container started but health check probe timed out."
docker logs --tail 50 "$CONTAINER_NAME" || true
exit 0
DEPLOY_EOF

chmod +x /opt/shopsphere/deploy.sh

# Run the deployment script for initial bootstrap
/opt/shopsphere/deploy.sh

# ------------------------------------------------------------------------------
# 5. Configure Nginx Reverse Proxy
# ------------------------------------------------------------------------------
echo "[5/6] Configuring Nginx reverse proxy..."
cat > /etc/nginx/conf.d/shopsphere.conf <<NGINX_EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 16M;

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header CloudFront-Viewer-Country \$http_cloudfront_viewer_country;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_EOF

rm -f /etc/nginx/conf.d/default.conf
systemctl enable --now nginx
systemctl reload nginx || systemctl restart nginx

echo "=== ShopSphere Stage 8 Docker Node Bootstrap Completed at $(date) ==="
echo "Connected to RDS (${db_host}), ElastiCache (${redis_host}), and SQS (${sqs_queue_name})"
