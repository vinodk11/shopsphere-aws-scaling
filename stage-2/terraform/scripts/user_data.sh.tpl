#!/usr/bin/env bash
# ==============================================================================
# ShopSphere EC2 Bootstrap Script (Stage 2 - Decoupled Amazon RDS)
# Provisions: Node.js 20 LTS runtime, PostgreSQL 15 client tools, Nginx reverse proxy, ShopSphere App
# ==============================================================================

set -euo pipefail

# Redirect all output to logfile and console
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "===================================================================="
echo "[ShopSphere Bootstrap] Starting Stage 2 EC2 Compute Provisioning..."
echo "Architecture: Compute Tier on EC2 -> Database Tier on Amazon RDS"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
echo "===================================================================="

# ------------------------------------------------------------------------------
# 1. Update Operating System & Install Required Packages
# ------------------------------------------------------------------------------
echo "[1/6] Updating OS and installing packages (Node.js, PostgreSQL client, Nginx, Git)..."
dnf update -y
dnf install -y git nodejs npm postgresql15 nginx

# ------------------------------------------------------------------------------
# 2. Wait for Amazon RDS PostgreSQL to Accept Network Connections
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
# 3. Setup Application Directory & Source Code
# ------------------------------------------------------------------------------
echo "[3/6] Setting up ShopSphere application directory..."
mkdir -p /opt/shopsphere/app
mkdir -p /opt/shopsphere/repo

APP_REPO="${app_repo_url}"
if [ -n "$APP_REPO" ]; then
  echo "[3/6] Cloning ShopSphere application repository from $APP_REPO..."
  if git clone "$APP_REPO" /opt/shopsphere/repo; then
    echo "[3/6] Repository cloned successfully."
    # If the repository contains a dedicated Stage 2 or app subfolder, copy it over
    if [ -d "/opt/shopsphere/repo/stage-2/app" ]; then
      echo "[3/6] Copying application code from stage-2/app..."
      cp -r /opt/shopsphere/repo/stage-2/app/* /opt/shopsphere/app/
    elif [ -d "/opt/shopsphere/repo/shopsphere/stage-2/app" ]; then
      echo "[3/6] Copying application code from shopsphere/stage-2/app..."
      cp -r /opt/shopsphere/repo/shopsphere/stage-2/app/* /opt/shopsphere/app/
    elif [ -d "/opt/shopsphere/repo/app" ]; then
      echo "[3/6] Copying application code from app/..."
      cp -r /opt/shopsphere/repo/app/* /opt/shopsphere/app/
    fi
  else
    echo "[WARNING] Git clone failed; will use self-contained embedded Stage 2 application source."
  fi
fi

# Ensure package.json exists (embedded self-contained Stage 2 application code)
if [ ! -f /opt/shopsphere/app/package.json ]; then
  echo "[3/6] Writing embedded Stage 2 application source code..."
  mkdir -p /opt/shopsphere/app/db /opt/shopsphere/app/public

  cat << 'JSON_EOF' > /opt/shopsphere/app/package.json
{
  "name": "shopsphere-app",
  "version": "2.0.0",
  "description": "ShopSphere E-Commerce Application - Stage 2 (Decoupled Amazon RDS PostgreSQL)",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "morgan": "^1.10.0",
    "pg": "^8.11.5"
  }
}
JSON_EOF

  cat << 'SQL_INIT' > /opt/shopsphere/app/db/schema.sql
-- ==============================================================================
-- ShopSphere Database Schema & Seed Data (Stage 2 - Amazon RDS PostgreSQL)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 50,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(150) NOT NULL,
    shipping_address TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categories (id, name, description) VALUES
(1, 'Audio & Electronics', 'High fidelity audio equipment, noise-canceling gear, and accessories'),
(2, 'Wearables', 'Next-gen smart wearables, fitness trackers, and connected devices'),
(3, 'Smart Home', 'Connected smart lamps, voice hubs, and home automation systems'),
(4, 'Computer Peripherals', 'Productivity gear, mechanical keyboards, and precision peripherals')
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, category_id, name, description, price, stock_quantity, image_url) VALUES
(1, 1, 'CloudBeats ANC Wireless Headphones', 'Active noise cancelling wireless headphones with 40-hour battery life and spatial audio.', 199.99, 45, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60'),
(2, 2, 'ShopSphere Apex Smart Watch', 'AMOLED display, continuous ECG & SpO2 tracking, 7-day battery, and 5ATM water resistance.', 249.99, 30, 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60'),
(3, 1, 'UltraHD 4K Action Camera', 'Compact waterproof 4K/60fps camera with 6-axis gyro stabilization and dual screens.', 129.99, 25, 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=500&auto=format&fit=crop&q=60'),
(4, 3, 'Aurora Smart RGB Desk Lamp', 'Voice-controlled ambient lighting with custom gradients, timer routines, and adaptive brightness.', 49.99, 60, 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=500&auto=format&fit=crop&q=60'),
(5, 4, 'CyberDeck RGB Mechanical Keyboard', 'Hot-swappable tactile mechanical switches, PBT keycaps, and aircraft-grade aluminum chassis.', 89.99, 40, 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60'),
(6, 1, 'HyperCharge 20000mAh Power Bank', '65W USB-C Power Delivery fast-charging power bank for laptops, tablets, and smartphones.', 39.99, 75, 'https://images.unsplash.com/photo-1609592426507-da665123d537?w=500&auto=format&fit=crop&q=60')
ON CONFLICT (id) DO NOTHING;

SELECT setval('categories_id_seq', COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval('products_id_seq', COALESCE((SELECT MAX(id) FROM products), 1));
SQL_INIT

  cat << 'SERVER_JS' > /opt/shopsphere/app/server.js
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'shopspheredb',
  user: process.env.DB_USER || 'shopsphere_user',
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

app.use(cors());
app.use(express.json());
app.use(morgan('combined'));
app.use(express.static(path.join(__dirname, 'public')));

async function initializeDatabase() {
  const schemaPath = path.join(__dirname, 'db', 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    try {
      console.log('[DB] Applying schema to Amazon RDS...');
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      await pool.query(schemaSql);
      console.log('[DB] Schema successfully initialized on Amazon RDS.');
    } catch (err) {
      console.error('[DB] Schema initialization notice:', err.message);
    }
  }
}

app.get('/health', async (req, res) => {
  let dbStatus = 'disconnected';
  let dbLatencyMs = null;
  let dbVersion = null;

  const start = Date.now();
  try {
    const dbRes = await pool.query('SELECT NOW() as now, version() as version');
    if (dbRes.rows.length > 0) {
      dbStatus = 'connected';
      dbLatencyMs = Date.now() - start;
      dbVersion = dbRes.rows[0].version ? dbRes.rows[0].version.split(' ')[1] : '15.x';
    }
  } catch (err) {
    dbStatus = `error: ${err.message}`;
  }

  const isHealthy = dbStatus === 'connected';

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    stage: 'Stage 2: EC2 + Amazon RDS PostgreSQL (Decoupled Database)',
    application: 'ShopSphere Application Server',
    version: '2.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: {
      engine: 'Amazon RDS PostgreSQL',
      version: dbVersion,
      status: dbStatus,
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432', 10),
      name: process.env.DB_NAME,
      latencyMs: dbLatencyMs
    },
    system: {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      totalMemMB: Math.round(os.totalmem() / 1024 / 1024),
      freeMemMB: Math.round(os.freemem() / 1024 / 1024)
    }
  });
});

app.get('/api/system/info', (req, res) => {
  res.json({
    appName: 'ShopSphere Web App',
    version: '2.0.0',
    stage: 'Stage 2 - EC2 Compute Tier + Amazon RDS Decoupled Database Tier',
    architecture: 'Internet -> Nginx (:80) -> Node.js (:8080) [EC2 Public Subnet] -> Amazon RDS PostgreSQL (:5432) [Private DB Subnets]',
    hostname: os.hostname(),
    nodeVersion: process.version,
    databaseHost: process.env.DB_HOST,
    memoryUsageMB: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024),
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
    }
  });
});

app.get('/api/products', async (req, res) => {
  try {
    const query = `
      SELECT p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url,
             c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.id ASC;
    `;
    const { rows } = await pool.query(query);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

app.get('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const query = `
      SELECT p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url,
             c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = $1;
    `;
    const { rows } = await pool.query(query, [id]);
    if (rows.length === 0) return res.status(404).json({ success: false, error: 'Product not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

app.get('/api/orders', async (req, res) => {
  try {
    const query = `
      SELECT o.id, o.customer_name, o.customer_email, o.shipping_address,
             o.total_amount, o.status, o.created_at,
             json_agg(json_build_object(
               'product_id', oi.product_id,
               'product_name', p.name,
               'quantity', oi.quantity,
               'unit_price', oi.unit_price
             )) AS items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      GROUP BY o.id
      ORDER BY o.created_at DESC
      LIMIT 20;
    `;
    const { rows } = await pool.query(query);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

app.post('/api/orders', async (req, res) => {
  const client = await pool.connect();
  try {
    const { customerName, customerEmail, shippingAddress, items } = req.body;
    if (!customerName || !customerEmail || !shippingAddress || !items || !items.length) {
      return res.status(400).json({ success: false, error: 'Missing required fields' });
    }

    await client.query('BEGIN');
    let totalAmount = 0;
    const validatedItems = [];

    for (const item of items) {
      const prodRes = await client.query('SELECT id, name, price, stock_quantity FROM products WHERE id = $1 FOR UPDATE', [item.productId]);
      if (prodRes.rows.length === 0) throw new Error(`Product ID ${item.productId} not found`);
      const product = prodRes.rows[0];
      if (product.stock_quantity < item.quantity) throw new Error(`Insufficient stock for ${product.name}`);

      const itemTotal = parseFloat(product.price) * item.quantity;
      totalAmount += itemTotal;
      await client.query('UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2', [item.quantity, item.productId]);
      validatedItems.push({ productId: product.id, quantity: item.quantity, unitPrice: product.price });
    }

    const orderRes = await client.query(
      `INSERT INTO orders (customer_name, customer_email, shipping_address, total_amount, status)
       VALUES ($1, $2, $3, $4, 'COMPLETED') RETURNING id, created_at`,
      [customerName, customerEmail, shippingAddress, totalAmount.toFixed(2)]
    );
    const orderId = orderRes.rows[0].id;

    for (const vItem of validatedItems) {
      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, unit_price)
         VALUES ($1, $2, $3, $4)`,
        [orderId, vItem.productId, vItem.quantity, vItem.unitPrice]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({
      success: true,
      message: 'Order placed successfully on Amazon RDS',
      orderId: orderId,
      totalAmount: totalAmount.toFixed(2),
      createdAt: orderRes.rows[0].created_at
    });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(400).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, async () => {
  console.log(`[ShopSphere] Stage 2 Server running on port ${PORT}`);
  await initializeDatabase();
});
SERVER_JS

  cat << 'HTML_DOC' > /opt/shopsphere/app/public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ShopSphere - Stage 2: EC2 + Amazon RDS</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
</head>
<body>
  <div class="stage-banner">
    <div class="container banner-content">
      <span class="badge">AWS Stage 2</span>
      <span class="stage-desc">Compute on EC2 (Public Subnet) &bull; Managed Database on Amazon RDS PostgreSQL (Private DB Subnets)</span>
      <div id="systemHealthBadge" class="health-badge"><span class="pulse"></span> Checking System...</div>
    </div>
  </div>
  <header class="navbar">
    <div class="container nav-container">
      <div class="brand">
        <div class="logo-icon">🪐</div>
        <div>
          <h1>ShopSphere</h1>
          <span class="tagline">AWS Architecture Evolution &bull; Stage 2</span>
        </div>
      </div>
      <div class="nav-actions">
        <button id="systemInfoBtn" class="btn btn-secondary">Architecture Info</button>
        <button id="cartBtn" class="btn btn-primary">
          <span>🛒 Cart</span>
          <span id="cartCount" class="cart-count">0</span>
        </button>
      </div>
    </div>
  </header>
  <section class="hero">
    <div class="container">
      <h2>Next-Gen Hardware & Peripherals</h2>
      <p>Demonstrating decoupled database architecture using Amazon RDS PostgreSQL with multi-tier VPC isolation.</p>
    </div>
  </section>
  <main class="container main-content">
    <div class="section-header">
      <h3>Featured Products</h3>
      <span id="productCounter" class="counter-text">Loading catalog...</span>
    </div>
    <div id="productGrid" class="product-grid"></div>
  </main>
  <div id="infoModal" class="modal">
    <div class="modal-content">
      <div class="modal-header">
        <h3>Architecture Details (Stage 2)</h3>
        <button class="close-btn" id="closeInfoModal">&times;</button>
      </div>
      <div class="modal-body">
        <div class="arch-box">
          <code>Internet &rarr; Nginx (:80) &rarr; Node.js Express (:8080) [EC2 Public Subnet] &rarr; Amazon RDS PostgreSQL (:5432) [Private DB Subnets]</code>
        </div>
        <div class="metrics-grid" id="systemMetrics">
          <div class="metric-card"><span class="metric-label">Status</span><span class="metric-val" id="metricStatus">-</span></div>
          <div class="metric-card"><span class="metric-label">Database Tier</span><span class="metric-val" id="metricDb">-</span></div>
          <div class="metric-card"><span class="metric-label">Server Uptime</span><span class="metric-val" id="metricUptime">-</span></div>
          <div class="metric-card"><span class="metric-label">Host Memory Free</span><span class="metric-val" id="metricMem">-</span></div>
        </div>
        <h4 style="margin-top: 1.5rem; margin-bottom: 0.5rem;">Recent Orders in Amazon RDS</h4>
        <div id="ordersList" class="orders-list">Loading orders...</div>
      </div>
    </div>
  </div>
  <div id="cartModal" class="modal">
    <div class="modal-content">
      <div class="modal-header">
        <h3>Your Shopping Cart</h3>
        <button class="close-btn" id="closeCartModal">&times;</button>
      </div>
      <div class="modal-body">
        <div id="cartItems" class="cart-items"><p class="empty-cart-msg">Your cart is empty.</p></div>
        <div class="cart-summary">
          <div class="total-row"><span>Total:</span><span id="cartTotal" class="total-amount">$0.00</span></div>
        </div>
        <form id="checkoutForm" class="checkout-form" style="display: none;">
          <h4>Checkout Details</h4>
          <div class="form-group"><label>Full Name</label><input type="text" id="custName" required value="Alex Developer"></div>
          <div class="form-group"><label>Email Address</label><input type="email" id="custEmail" required value="alex@example.com"></div>
          <div class="form-group"><label>Shipping Address</label><textarea id="custAddress" required rows="2">100 Cloud Way, Suite 404, Seattle, WA 98101</textarea></div>
          <button type="submit" id="submitOrderBtn" class="btn btn-primary btn-block">Confirm & Place Order (RDS ACID)</button>
        </form>
      </div>
    </div>
  </div>
  <footer class="footer">
    <div class="container footer-content">
      <p>&copy; 2026 ShopSphere Project &bull; Built for AWS Architecture Learning</p>
      <p class="footer-sub">Stage 2: Single EC2 + Amazon RDS PostgreSQL &bull; Managed by Terraform</p>
    </div>
  </footer>
  <script>
    let cart = [], products = [];
    async function loadProducts() {
      try {
        const res = await fetch('/api/products');
        const data = await res.json();
        if (data.success) {
          products = data.data;
          document.getElementById('productGrid').innerHTML = products.map(p => `
            <div class="product-card">
              <div class="img-wrapper">
                <img src="${p.image_url}" alt="${p.name}" loading="lazy">
                <span class="category-tag">${p.category_name || 'General'}</span>
              </div>
              <div class="card-body">
                <h4 class="product-title">${p.name}</h4>
                <p class="product-desc">${p.description}</p>
                <div class="card-footer">
                  <div class="price-box">
                    <span class="price-val">$${parseFloat(p.price).toFixed(2)}</span>
                    <span class="stock-badge">In Stock: ${p.stock_quantity}</span>
                  </div>
                  <button class="btn btn-sm btn-primary" onclick="addToCart(${p.id})">Add to Cart</button>
                </div>
              </div>
            </div>
          `).join('');
          document.getElementById('productCounter').innerText = products.length + ' Products Available';
        }
      } catch (err) {
        document.getElementById('productGrid').innerHTML = '<p class="error-msg">Error loading catalog: ' + err.message + '</p>';
      }
    }
    async function checkHealth() {
      try {
        const res = await fetch('/health');
        const data = await res.json();
        const badge = document.getElementById('systemHealthBadge');
        if (data.status === 'UP') {
          badge.className = 'health-badge health-up';
          badge.innerHTML = '<span class="pulse green"></span> Amazon RDS Connected (' + data.database.latencyMs + 'ms)';
        } else {
          badge.className = 'health-badge health-down';
          badge.innerHTML = '<span class="pulse red"></span> RDS Issue';
        }
      } catch (e) {
        const badge = document.getElementById('systemHealthBadge');
        badge.className = 'health-badge health-down';
        badge.innerHTML = '<span class="pulse red"></span> Server Offline';
      }
    }
    function addToCart(productId) {
      const prod = products.find(p => p.id === productId);
      if (!prod) return;
      const existing = cart.find(item => item.productId === productId);
      if (existing) { existing.quantity += 1; } else { cart.push({ productId: prod.id, name: prod.name, price: parseFloat(prod.price), quantity: 1 }); }
      updateCartUI();
    }
    function updateCartUI() {
      const count = cart.reduce((sum, item) => sum + item.quantity, 0);
      document.getElementById('cartCount').innerText = count;
      const total = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      document.getElementById('cartTotal').innerText = '$' + total.toFixed(2);
      const cartItemsDiv = document.getElementById('cartItems');
      const checkoutForm = document.getElementById('checkoutForm');
      if (cart.length === 0) {
        cartItemsDiv.innerHTML = '<p class="empty-cart-msg">Your cart is empty.</p>';
        checkoutForm.style.display = 'none';
      } else {
        checkoutForm.style.display = 'block';
        cartItemsDiv.innerHTML = cart.map((item, idx) => `
          <div class="cart-item-row">
            <div><strong>${item.name}</strong><div class="item-calc">$${item.price.toFixed(2)} &times; ${item.quantity}</div></div>
            <div class="item-actions"><span class="item-subtotal">$${(item.price * item.quantity).toFixed(2)}</span><button class="remove-btn" onclick="removeFromCart(${idx})">&times;</button></div>
          </div>
        `).join('');
      }
    }
    function removeFromCart(idx) { cart.splice(idx, 1); updateCartUI(); }
    document.getElementById('checkoutForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = document.getElementById('submitOrderBtn');
      btn.disabled = true; btn.innerText = 'Processing Order...';
      const payload = {
        customerName: document.getElementById('custName').value,
        customerEmail: document.getElementById('custEmail').value,
        shippingAddress: document.getElementById('custAddress').value,
        items: cart.map(i => ({ productId: i.productId, quantity: i.quantity }))
      };
      try {
        const res = await fetch('/api/orders', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        const data = await res.json();
        if (data.success) {
          alert('🎉 Order #' + data.orderId + ' placed on Amazon RDS! Total: $' + data.totalAmount);
          cart = []; updateCartUI(); document.getElementById('cartModal').style.display = 'none'; loadProducts();
        } else { alert('Error: ' + data.error); }
      } catch (err) { alert('Failed: ' + err.message); }
      finally { btn.disabled = false; btn.innerText = 'Confirm & Place Order (RDS ACID)'; }
    });
    const cartModal = document.getElementById('cartModal');
    const infoModal = document.getElementById('infoModal');
    document.getElementById('cartBtn').onclick = () => { updateCartUI(); cartModal.style.display = 'block'; };
    document.getElementById('closeCartModal').onclick = () => { cartModal.style.display = 'none'; };
    document.getElementById('systemInfoBtn').onclick = async () => {
      infoModal.style.display = 'block';
      try {
        const healthRes = await fetch('/health');
        const hData = await healthRes.json();
        document.getElementById('metricStatus').innerText = hData.status;
        document.getElementById('metricDb').innerText = hData.database.engine + ' (' + (hData.database.latencyMs || 0) + 'ms)';
        document.getElementById('metricUptime').innerText = hData.uptimeSeconds + 's';
        document.getElementById('metricMem').innerText = hData.system.freeMemMB + 'MB / ' + hData.system.totalMemMB + 'MB';
        const ordRes = await fetch('/api/orders');
        const oData = await ordRes.json();
        const ordDiv = document.getElementById('ordersList');
        if (oData.count === 0) { ordDiv.innerHTML = '<p>No orders placed yet.</p>'; } else {
          ordDiv.innerHTML = oData.data.map(o => `
            <div class="order-chip"><strong>#${o.id} - ${o.customer_name}</strong><span>$${parseFloat(o.total_amount).toFixed(2)} &bull; ${new Date(o.created_at).toLocaleTimeString()}</span></div>
          `).join('');
        }
      } catch (e) {}
    };
    document.getElementById('closeInfoModal').onclick = () => { infoModal.style.display = 'none'; };
    window.onclick = (e) => { if (e.target === cartModal) cartModal.style.display = 'none'; if (e.target === infoModal) infoModal.style.display = 'none'; };
    loadProducts(); checkHealth(); setInterval(checkHealth, 15000);
  </script>
</body>
</html>
HTML_DOC

  cat << 'CSS_DOC' > /opt/shopsphere/app/public/styles.css
:root {
  --primary: #4f46e5;
  --primary-hover: #4338ca;
  --secondary: #0ea5e9;
  --bg-dark: #0f172a;
  --bg-card: #1e293b;
  --bg-card-hover: #26354a;
  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --border-color: #334155;
  --accent-green: #10b981;
  --accent-red: #ef4444;
  --accent-amber: #f59e0b;
  --radius: 12px;
  --shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Plus Jakarta Sans', sans-serif; background-color: var(--bg-dark); color: var(--text-main); line-height: 1.5; min-height: 100vh; display: flex; flex-direction: column; }
.container { max-width: 1200px; margin: 0 auto; padding: 0 1.5rem; }
.stage-banner { background: linear-gradient(90deg, #0c4a6e 0%, #0369a1 50%, #4338ca 100%); border-bottom: 1px solid #0284c7; padding: 0.6rem 0; font-size: 0.85rem; }
.banner-content { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
.badge { background: #0284c7; color: #fff; font-weight: 700; padding: 0.2rem 0.6rem; border-radius: 6px; text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }
.stage-desc { color: #e0f2fe; flex: 1; }
.health-badge { display: flex; align-items: center; gap: 0.5rem; font-family: 'JetBrains Mono', monospace; font-size: 0.8rem; background: rgba(0, 0, 0, 0.4); padding: 0.25rem 0.75rem; border-radius: 9999px; border: 1px solid var(--border-color); }
.pulse { width: 8px; height: 8px; border-radius: 50%; background-color: var(--accent-amber); display: inline-block; }
.pulse.green { background-color: var(--accent-green); box-shadow: 0 0 8px var(--accent-green); }
.pulse.red { background-color: var(--accent-red); box-shadow: 0 0 8px var(--accent-red); }
.navbar { background-color: rgba(15, 23, 42, 0.95); backdrop-filter: blur(8px); border-bottom: 1px solid var(--border-color); padding: 1rem 0; position: sticky; top: 0; z-index: 50; }
.nav-container { display: flex; justify-content: space-between; align-items: center; }
.brand { display: flex; align-items: center; gap: 0.75rem; }
.logo-icon { font-size: 2rem; }
.brand h1 { font-size: 1.4rem; font-weight: 800; }
.tagline { font-size: 0.75rem; color: var(--text-muted); display: block; }
.nav-actions { display: flex; gap: 0.75rem; align-items: center; }
.btn { font-family: inherit; font-size: 0.9rem; font-weight: 600; padding: 0.6rem 1.2rem; border-radius: 8px; border: none; cursor: pointer; display: inline-flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease; }
.btn-primary { background-color: var(--primary); color: white; }
.btn-primary:hover { background-color: var(--primary-hover); transform: translateY(-1px); }
.btn-secondary { background-color: var(--bg-card); color: var(--text-main); border: 1px solid var(--border-color); }
.btn-secondary:hover { background-color: var(--bg-card-hover); }
.btn-sm { padding: 0.4rem 0.8rem; font-size: 0.8rem; }
.btn-block { width: 100%; justify-content: center; padding: 0.8rem; }
.cart-count { background: white; color: var(--primary); font-size: 0.75rem; font-weight: 800; border-radius: 9999px; padding: 0.15rem 0.45rem; }
.hero { padding: 3rem 0 2rem; text-align: center; background: radial-gradient(circle at top, rgba(14, 165, 233, 0.15) 0%, transparent 70%); }
.hero h2 { font-size: 2.4rem; font-weight: 800; margin-bottom: 0.75rem; }
.hero p { color: var(--text-muted); max-width: 600px; margin: 0 auto; font-size: 1.05rem; }
.main-content { flex: 1; padding-bottom: 4rem; }
.section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; padding-bottom: 0.75rem; border-bottom: 1px solid var(--border-color); }
.section-header h3 { font-size: 1.25rem; font-weight: 700; }
.counter-text { color: var(--text-muted); font-size: 0.85rem; }
.product-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1.5rem; }
.product-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius); overflow: hidden; display: flex; flex-direction: column; transition: transform 0.2s ease, border-color 0.2s ease; }
.product-card:hover { transform: translateY(-4px); border-color: var(--secondary); }
.img-wrapper { position: relative; height: 200px; overflow: hidden; background-color: #000; }
.img-wrapper img { width: 100%; height: 100%; object-fit: cover; }
.category-tag { position: absolute; top: 0.75rem; left: 0.75rem; background: rgba(15, 23, 42, 0.8); backdrop-filter: blur(4px); color: #cbd5e1; font-size: 0.7rem; font-weight: 600; padding: 0.25rem 0.5rem; border-radius: 4px; }
.card-body { padding: 1.25rem; display: flex; flex-direction: column; flex: 1; }
.product-title { font-size: 1.05rem; font-weight: 700; margin-bottom: 0.5rem; }
.product-desc { font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1.25rem; flex: 1; }
.card-footer { display: flex; justify-content: space-between; align-items: center; border-top: 1px solid rgba(255, 255, 255, 0.06); padding-top: 0.75rem; }
.price-box { display: flex; flex-direction: column; }
.price-val { font-size: 1.2rem; font-weight: 800; color: #fff; }
.stock-badge { font-size: 0.7rem; color: var(--accent-green); }
.modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0, 0, 0, 0.75); backdrop-filter: blur(4px); z-index: 100; overflow-y: auto; }
.modal-content { background: var(--bg-card); max-width: 560px; margin: 5vh auto; border-radius: var(--radius); border: 1px solid var(--border-color); box-shadow: var(--shadow); overflow: hidden; }
.modal-header { padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; }
.close-btn { background: none; border: none; color: var(--text-muted); font-size: 1.5rem; cursor: pointer; }
.modal-body { padding: 1.5rem; }
.arch-box { background: #0f172a; padding: 0.85rem; border-radius: 8px; border: 1px solid #0284c7; font-size: 0.8rem; font-family: 'JetBrains Mono', monospace; margin-bottom: 1rem; color: #38bdf8; word-break: break-all; }
.metrics-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.metric-card { background: #0f172a; padding: 0.75rem; border-radius: 6px; border: 1px solid #334155; }
.metric-label { font-size: 0.75rem; color: var(--text-muted); display: block; }
.metric-val { font-size: 0.95rem; font-weight: 700; color: #fff; }
.orders-list { max-height: 180px; overflow-y: auto; display: flex; flex-direction: column; gap: 0.5rem; }
.order-chip { background: #0f172a; padding: 0.5rem 0.75rem; border-radius: 6px; font-size: 0.8rem; display: flex; justify-content: space-between; border: 1px solid #334155; }
.cart-items { margin-bottom: 1rem; max-height: 200px; overflow-y: auto; }
.cart-item-row { display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0; border-bottom: 1px solid #334155; }
.item-calc { font-size: 0.75rem; color: var(--text-muted); }
.item-actions { display: flex; align-items: center; gap: 0.75rem; }
.remove-btn { background: none; border: none; color: var(--accent-red); font-size: 1.1rem; cursor: pointer; }
.cart-summary { border-top: 2px solid var(--border-color); padding: 0.75rem 0 1rem; }
.total-row { display: flex; justify-content: space-between; font-size: 1.1rem; font-weight: 700; }
.total-amount { color: var(--secondary); }
.checkout-form h4 { margin-bottom: 0.75rem; font-size: 1rem; border-top: 1px solid #334155; padding-top: 0.75rem; }
.form-group { margin-bottom: 0.75rem; }
.form-group label { display: block; font-size: 0.8rem; color: var(--text-muted); margin-bottom: 0.25rem; }
.form-group input, .form-group textarea { width: 100%; padding: 0.5rem 0.75rem; background: #0f172a; border: 1px solid var(--border-color); border-radius: 6px; color: #fff; font-family: inherit; font-size: 0.85rem; }
.footer { margin-top: auto; border-top: 1px solid var(--border-color); padding: 2rem 0; background-color: rgba(15, 23, 42, 0.95); text-align: center; font-size: 0.85rem; color: var(--text-muted); }
.footer-sub { font-size: 0.75rem; margin-top: 0.25rem; }
CSS_DOC
fi

# ------------------------------------------------------------------------------
# 4. Write Application Environment File & Install Dependencies
# ------------------------------------------------------------------------------
echo "[4/6] Writing .env configuration pointing to Amazon RDS (${db_host}:${db_port})..."
cat << ENV_EOF > /opt/shopsphere/app/.env
PORT=${app_port}
NODE_ENV=production
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
ENV_EOF

chmod 600 /opt/shopsphere/app/.env
chown -R ec2-user:ec2-user /opt/shopsphere

echo "[4/6] Installing application dependencies via npm..."
cd /opt/shopsphere/app
sudo -u ec2-user npm install --omit=dev

# ------------------------------------------------------------------------------
# 5. Configure Systemd Service for ShopSphere
# ------------------------------------------------------------------------------
echo "[5/6] Configuring systemd service for ShopSphere..."
cat << 'SERVICE_EOF' > /etc/systemd/system/shopsphere.service
[Unit]
Description=ShopSphere Application Server (Stage 2 - Decoupled Amazon RDS)
After=network.target

[Service]
Type=simple
User=ec2-user
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
# 6. Configure Nginx Reverse Proxy (Port 80 -> Application Port)
# ------------------------------------------------------------------------------
echo "[6/6] Configuring Nginx reverse proxy..."
cat << NGINX_CONF > /etc/nginx/conf.d/shopsphere.conf
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
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_CONF

systemctl enable --now nginx
systemctl reload nginx || systemctl restart nginx

# ------------------------------------------------------------------------------
# Verification & Health Check
# ------------------------------------------------------------------------------
echo "[Verification] Verifying ShopSphere service health and RDS connectivity..."
sleep 5
for i in {1..15}; do
  if curl -sf http://127.0.0.1:${app_port}/health > /dev/null 2>&1; then
    echo "[ShopSphere Bootstrap] Successfully verified application health on port ${app_port}!"
    break
  fi
  echo "Waiting for ShopSphere service to initialize... ($i/15)"
  sleep 3
done

echo "===================================================================="
echo "[ShopSphere Bootstrap] Stage 2 EC2 Compute Tier setup completed!"
echo "Connected to Amazon RDS Endpoint: ${db_host}"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
echo "===================================================================="
