#!/bin/bash
# ==============================================================================
# ShopSphere Stage 1 Bootstrap Script (Single EC2 Monolith + Colocated Database)
# Rendered by Terraform templatefile() and executed as EC2 user_data.
# ==============================================================================
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== ShopSphere Stage 1 Bootstrap Starting at $(date) ==="

# ------------------------------------------------------------------------------
# 1. Update OS and Install Packages
# ------------------------------------------------------------------------------
echo "[1/6] Updating OS and installing dependencies (Node.js, PostgreSQL 15, Nginx, Git)..."
dnf update -y
dnf install -y git nodejs npm postgresql15-server postgresql15 nginx

# ------------------------------------------------------------------------------
# 2. Configure & Start PostgreSQL 15
# ------------------------------------------------------------------------------
echo "[2/6] Initializing and configuring PostgreSQL 15..."
if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
  postgresql-setup --initdb
fi

# Configure pg_hba.conf for local md5/password authentication
cat > /var/lib/pgsql/data/pg_hba.conf <<'PGHBA_EOF'
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
PGHBA_EOF

systemctl enable --now postgresql

# Create database and application role
sudo -u postgres psql <<SQL_EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
    CREATE ROLE ${db_user} WITH LOGIN PASSWORD '${db_password}';
  ELSE
    ALTER ROLE ${db_user} WITH PASSWORD '${db_password}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
SQL_EOF

sudo -u postgres psql -d "${db_name}" <<SQL_SCHEMA_EOF
GRANT ALL ON SCHEMA public TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${db_user};
SQL_SCHEMA_EOF

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
if [ -d "/opt/shopsphere/repo/stage-1/app" ]; then
  echo "Deploying application code from stage-1/app..."
  cp -r /opt/shopsphere/repo/stage-1/app/* /opt/shopsphere/app/
elif [ -d "/opt/shopsphere/repo/app" ]; then
  cp -r /opt/shopsphere/repo/app/* /opt/shopsphere/app/
fi

# Apply initial database schema and seed data if present
if [ -f "/opt/shopsphere/app/db/schema.sql" ]; then
  echo "Applying database schema and seed data..."
  sudo -u postgres psql -d "${db_name}" -f /opt/shopsphere/app/db/schema.sql || true
fi

# ------------------------------------------------------------------------------
# 4. Write Environment Configuration & Install Node Dependencies
# ------------------------------------------------------------------------------
echo "[4/6] Writing .env configuration and installing npm packages..."
cat > /opt/shopsphere/app/.env <<ENV_EOF
PORT=${app_port}
NODE_ENV=production
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
ENV_EOF

chmod 600 /opt/shopsphere/app/.env

# Create dedicated system user and home directory
id -u shopsphere &>/dev/null || useradd -r -m -d /home/shopsphere -s /bin/false shopsphere
mkdir -p /home/shopsphere
chown -R shopsphere:shopsphere /home/shopsphere

# Install npm dependencies using clean temporary cache
cd /opt/shopsphere/app
export HOME=/root
npm install --omit=dev --cache /tmp/.npm
chown -R shopsphere:shopsphere /opt/shopsphere /home/shopsphere

# ------------------------------------------------------------------------------
# 5. Configure Systemd Service for ShopSphere
# ------------------------------------------------------------------------------
echo "[5/6] Creating systemd service..."
cat > /etc/systemd/system/shopsphere.service <<'SERVICE_EOF'
[Unit]
Description=ShopSphere Monolith Application (Stage 1)
After=network.target postgresql.service
Requires=postgresql.service

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
    echo "✅ ShopSphere Stage 1 application is UP and healthy!"
    break
  fi
  echo "Waiting for ShopSphere service to initialize... ($i/30)"
  sleep 3
done

echo "=== ShopSphere Stage 1 Bootstrap Completed at $(date) ==="
