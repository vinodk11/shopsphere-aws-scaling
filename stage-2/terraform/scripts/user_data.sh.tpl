#!/bin/bash
# ==============================================================================
# ShopSphere Stage 2 Bootstrap Script (EC2 Compute + Amazon RDS PostgreSQL)
# Rendered by Terraform templatefile() and executed as EC2 user_data.
# ==============================================================================
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== ShopSphere Stage 2 Bootstrap Starting at $(date) ==="

# ------------------------------------------------------------------------------
# 1. Update OS and Install Packages
# ------------------------------------------------------------------------------
echo "[1/6] Updating OS and installing packages (Node.js, PostgreSQL client, Nginx, Git)..."
dnf update -y
dnf install -y git nodejs npm postgresql15 nginx

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
# 3. Clone Application Repository and Setup Source Code
# ------------------------------------------------------------------------------
echo "[3/6] Setting up ShopSphere application source code..."
mkdir -p /opt/shopsphere
cd /opt/shopsphere

APP_REPO="${app_repo_url}"
if [ -z "$APP_REPO" ] || [ "$APP_REPO" = "https://github.com/kbhujbal/ShopSphere---E-commerce-Microservice-Platform.git" ]; then
  APP_REPO="https://github.com/vinodk11/shopsphere-aws-scaling.git"
fi

if [ ! -d repo ]; then
  echo "Cloning repository from $APP_REPO..."
  git clone "$APP_REPO" repo || git clone "https://github.com/vinodk11/shopsphere-aws-scaling.git" repo
else
  echo "Repository already exists, pulling latest..."
  cd repo && git pull && cd ..
fi

mkdir -p /opt/shopsphere/app
if [ -d "/opt/shopsphere/repo/stage-2/app" ]; then
  echo "Deploying application code from stage-2/app..."
  cp -r /opt/shopsphere/repo/stage-2/app/* /opt/shopsphere/app/
elif [ -d "/opt/shopsphere/repo/app" ]; then
  cp -r /opt/shopsphere/repo/app/* /opt/shopsphere/app/
fi

# Apply initial database schema to Amazon RDS if present
if [ -f "/opt/shopsphere/app/db/schema.sql" ]; then
  echo "Applying database schema to Amazon RDS..."
  PGPASSWORD="${db_password}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -f /opt/shopsphere/app/db/schema.sql || true
fi

# ------------------------------------------------------------------------------
# 4. Write Environment Configuration & Install Node Dependencies
# ------------------------------------------------------------------------------
echo "[4/6] Writing .env configuration pointing to Amazon RDS (${db_host}:${db_port})..."
cat > /opt/shopsphere/app/.env <<ENV_EOF
PORT=${app_port}
NODE_ENV=production
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
ENV_EOF

chmod 600 /opt/shopsphere/app/.env

# Create dedicated system user and set permissions
id -u shopsphere &>/dev/null || useradd -r -s /bin/false shopsphere
chown -R shopsphere:shopsphere /opt/shopsphere/app

cd /opt/shopsphere/app
sudo -u shopsphere npm install --omit=dev

# ------------------------------------------------------------------------------
# 5. Configure Systemd Service for ShopSphere
# ------------------------------------------------------------------------------
echo "[5/6] Creating systemd service..."
cat > /etc/systemd/system/shopsphere.service <<'SERVICE_EOF'
[Unit]
Description=ShopSphere Application Server (Stage 2 - Decoupled Amazon RDS)
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
systemctl enable --now shopsphere.service

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
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_EOF

rm -f /etc/nginx/conf.d/default.conf
systemctl enable --now nginx
systemctl reload nginx || systemctl restart nginx

# ------------------------------------------------------------------------------
# Health Verification
# ------------------------------------------------------------------------------
echo "Verifying application health on port ${app_port}..."
sleep 5
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${app_port}/health" > /dev/null 2>&1; then
    echo "✅ ShopSphere Stage 2 application is UP and healthy!"
    break
  fi
  echo "Waiting for ShopSphere service to initialize... ($i/30)"
  sleep 3
done

echo "=== ShopSphere Stage 2 Bootstrap Completed at $(date) ==="
echo "Connected to Amazon RDS Endpoint: ${db_host}"
