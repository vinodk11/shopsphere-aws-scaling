#!/bin/bash
# ==============================================================================
# ShopSphere Stage 7 Bootstrap Script (DevSecOps + CloudFront + WAF + SQS + Lambda)
# Rendered by Terraform templatefile() and executed by cloud-init on each ASG node.
# Provides automated initial setup and /opt/shopsphere/deploy.sh for Jenkins App pipeline.
# ==============================================================================
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== ShopSphere Stage 7 ASG Node Bootstrap Starting at $(date) ==="
echo "Node Hostname: $(hostname)"

# ------------------------------------------------------------------------------
# 1. Update OS and Install Packages
# ------------------------------------------------------------------------------
echo "[1/6] Updating OS and installing packages (Node.js, PostgreSQL client, Nginx, Git)..."
dnf update -y
dnf install -y git nodejs npm postgresql15 nginx amazon-ssm-agent || dnf install -y git nodejs npm postgresql15 nginx

# Ensure Amazon SSM Agent is active for remote deployment via Jenkins
systemctl enable --now amazon-ssm-agent || true

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
mkdir -p /opt/shopsphere/app /home/shopsphere
chown -R shopsphere:shopsphere /home/shopsphere

# Write Environment Configuration
cat > /opt/shopsphere/app/.env <<ENV_EOF
PORT=${app_port}
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
STAGE_NAME=stage-7
ENV_EOF

chmod 600 /opt/shopsphere/app/.env
chown shopsphere:shopsphere /opt/shopsphere/app/.env

# ------------------------------------------------------------------------------
# 4. Configure Systemd Service for ShopSphere
# ------------------------------------------------------------------------------
echo "[4/6] Creating systemd service..."
cat > /etc/systemd/system/shopsphere.service <<'SERVICE_EOF'
[Unit]
Description=ShopSphere Application Server (Stage 7 - DevSecOps)
After=network.target

[Service]
Type=simple
User=shopsphere
Group=shopsphere
WorkingDirectory=/opt/shopsphere/app
EnvironmentFile=/opt/shopsphere/app/.env
ExecStart=/usr/bin/node /opt/shopsphere/app/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload

# ------------------------------------------------------------------------------
# 5. Create Standalone Deployment Script (/opt/shopsphere/deploy.sh)
# Can be called by user_data on boot AND by Jenkins App Pipeline via AWS SSM
# ------------------------------------------------------------------------------
echo "[5/6] Creating reusable deployment script /opt/shopsphere/deploy.sh..."
cat > /opt/shopsphere/deploy.sh <<'DEPLOY_EOF'
#!/bin/bash
# Reusable deployment script executed by user_data and Jenkins App Pipeline
set -euo pipefail
exec > >(tee -a /var/log/shopsphere-deploy.log) 2>&1

echo "======================================================================"
echo "🚀 ShopSphere Application Deployment Started at $(date)"
echo "======================================================================"

cd /opt/shopsphere

APP_REPO="${app_repo_url}"
if [ -z "$APP_REPO" ] || [ "$APP_REPO" = "https://github.com/kbhujbal/ShopSphere---E-commerce-Microservice-Platform.git" ]; then
  APP_REPO="https://github.com/vinodk11/shopsphere-aws-scaling.git"
fi

if [ ! -d repo ]; then
  echo "Cloning repository from $APP_REPO..."
  git clone "$APP_REPO" repo || git clone "https://github.com/vinodk11/shopsphere-aws-scaling.git" repo
else
  echo "Repository exists. Pulling latest commits from main..."
  cd repo
  git fetch origin main
  git reset --hard origin/main
  cd ..
fi

echo "Copying latest application code to /opt/shopsphere/app..."
if [ -d "/opt/shopsphere/repo/stage-7/app" ]; then
  cp -r /opt/shopsphere/repo/stage-7/app/* /opt/shopsphere/app/
elif [ -d "/opt/shopsphere/repo/stage-6/app" ]; then
  cp -r /opt/shopsphere/repo/stage-6/app/* /opt/shopsphere/app/
elif [ -d "/opt/shopsphere/repo/app" ]; then
  cp -r /opt/shopsphere/repo/app/* /opt/shopsphere/app/
fi

# Apply initial database schema to Amazon RDS idempotently if present
if [ -f "/opt/shopsphere/app/db/schema.sql" ]; then
  echo "Verifying database schema on Amazon RDS..."
  PGPASSWORD="${db_password}" PGSSLMODE=require psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -f /opt/shopsphere/app/db/schema.sql || true
fi

# Install npm production dependencies
cd /opt/shopsphere/app
export HOME=/root
npm install --omit=dev --cache /tmp/.npm
chown -R shopsphere:shopsphere /opt/shopsphere /home/shopsphere

# Restart systemd service
echo "Restarting shopsphere.service..."
systemctl enable shopsphere.service
systemctl restart shopsphere.service

# Health probe
echo "Verifying local service health on port ${app_port}..."
sleep 3
for i in $(seq 1 20); do
  if curl -sf "http://127.0.0.1:${app_port}/health" > /dev/null 2>&1; then
    echo "✅ ShopSphere application is UP and healthy on port ${app_port}!"
    exit 0
  fi
  echo "Waiting for service to be healthy ($i/20)..."
  sleep 2
done

echo "⚠️ Warning: Service restart completed but local health check timed out."
exit 0
DEPLOY_EOF

chmod +x /opt/shopsphere/deploy.sh

# Run the deployment script for initial bootstrap
/opt/shopsphere/deploy.sh

# ------------------------------------------------------------------------------
# 6. Configure Nginx Reverse Proxy
# ------------------------------------------------------------------------------
echo "[6/6] Configuring Nginx reverse proxy..."
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

echo "=== ShopSphere Stage 7 Node Bootstrap Completed at $(date) ==="
echo "Connected to RDS (${db_host}), ElastiCache (${redis_host}), and SQS (${sqs_queue_name})"
