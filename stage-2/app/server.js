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

// ==============================================================================
// PostgreSQL Connection Pool (Configured for Amazon RDS)
// ==============================================================================
const poolConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'shopspheredb',
  user: process.env.DB_USER || 'shopsphere_user',
  password: process.env.DB_PASSWORD || 'ShopSphere2026SecurePass!',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
};

// Enable SSL if specified in environment
if (process.env.DB_SSL === 'true') {
  poolConfig.ssl = { rejectUnauthorized: false };
}

const pool = new Pool(poolConfig);

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));
app.use(express.static(path.join(__dirname, 'public')));

// Database Self-Initialization / Verification Helper
async function initializeDatabase() {
  const schemaPath = path.join(__dirname, 'db', 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    try {
      console.log(`[DB] Verifying/initializing schema on Amazon RDS host: ${poolConfig.host}...`);
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      await pool.query(schemaSql);
      console.log('[DB] Schema and seed data successfully initialized on Amazon RDS.');
    } catch (err) {
      console.error('[DB] Schema initialization error/warning:', err.message);
    }
  }
}

// ----------------------------------------------------
// Health Check & Monitoring Endpoints
// ----------------------------------------------------
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
      host: process.env.DB_HOST || '127.0.0.1',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      name: process.env.DB_NAME || 'shopspheredb',
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

// System Info Endpoint
app.get('/api/system/info', (req, res) => {
  res.json({
    appName: 'ShopSphere Web App',
    version: '2.0.0',
    stage: 'Stage 2 - EC2 Compute Tier + Amazon RDS Decoupled Database Tier',
    architecture: 'Internet -> Nginx (:80) -> Node.js (:8080) [EC2 Public Subnet] -> Amazon RDS PostgreSQL (:5432) [Private DB Subnets]',
    hostname: os.hostname(),
    nodeVersion: process.version,
    databaseHost: process.env.DB_HOST || '127.0.0.1',
    memoryUsageMB: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024),
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
    }
  });
});

// ----------------------------------------------------
// Product Catalog APIs
// ----------------------------------------------------
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
    console.error('Error fetching products:', err);
    res.status(500).json({ success: false, error: 'Database query failed: ' + err.message });
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
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('Error fetching product:', err);
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

// ----------------------------------------------------
// Order Placement & Transaction APIs (ACID with RDS)
// ----------------------------------------------------
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
    console.error('Error fetching orders:', err);
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

app.post('/api/orders', async (req, res) => {
  const client = await pool.connect();
  try {
    const { customerName, customerEmail, shippingAddress, items } = req.body;

    if (!customerName || !customerEmail || !shippingAddress || !items || !items.length) {
      return res.status(400).json({
        success: false,
        error: 'Missing required order fields (customerName, customerEmail, shippingAddress, items)'
      });
    }

    await client.query('BEGIN');

    let totalAmount = 0;
    const validatedItems = [];

    // Atomically check inventory with row-level locks
    for (const item of items) {
      const prodRes = await client.query(
        'SELECT id, name, price, stock_quantity FROM products WHERE id = $1 FOR UPDATE',
        [item.productId]
      );
      if (prodRes.rows.length === 0) {
        throw new Error(`Product ID ${item.productId} not found`);
      }
      const product = prodRes.rows[0];
      if (product.stock_quantity < item.quantity) {
        throw new Error(`Insufficient stock for product '${product.name}' (Available: ${product.stock_quantity})`);
      }

      const itemTotal = parseFloat(product.price) * item.quantity;
      totalAmount += itemTotal;

      // Deduct stock
      await client.query(
        'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2',
        [item.quantity, item.productId]
      );

      validatedItems.push({
        productId: product.id,
        quantity: item.quantity,
        unitPrice: product.price
      });
    }

    // Insert main order record
    const orderRes = await client.query(
      `INSERT INTO orders (customer_name, customer_email, shipping_address, total_amount, status)
       VALUES ($1, $2, $3, $4, 'COMPLETED')
       RETURNING id, created_at`,
      [customerName, customerEmail, shippingAddress, totalAmount.toFixed(2)]
    );

    const orderId = orderRes.rows[0].id;

    // Insert line items
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
      message: 'Order created successfully on Amazon RDS',
      orderId: orderId,
      totalAmount: totalAmount.toFixed(2),
      createdAt: orderRes.rows[0].created_at
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Order transaction aborted:', err.message);
    res.status(400).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

// Fallback to index.html for SPA routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start Server
app.listen(PORT, async () => {
  console.log(`=============================================================`);
  console.log(` ShopSphere Application Server (Stage 2)`);
  console.log(` Architecture: EC2 App Tier + Amazon RDS PostgreSQL DB Tier`);
  console.log(` Port: ${PORT}`);
  console.log(` RDS Host: ${poolConfig.host}:${poolConfig.port}`);
  console.log(` Database: ${poolConfig.database} (User: ${poolConfig.user})`);
  console.log(`=============================================================`);

  await initializeDatabase();
});

// Graceful Shutdown Handlers
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received. Closing Amazon RDS connection pool...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT signal received. Closing Amazon RDS connection pool...');
  await pool.end();
  process.exit(0);
});
