const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { Pool } = require('pg');
const redis = require('redis');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// ==============================================================================
// 1. PostgreSQL Connection Pool (Amazon RDS PostgreSQL)
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

if (process.env.DB_SSL === 'true' || (poolConfig.host && poolConfig.host.includes('rds.amazonaws.com'))) {
  poolConfig.ssl = { rejectUnauthorized: false };
}

const pool = new Pool(poolConfig);

// ==============================================================================
// 2. Redis Client (Amazon ElastiCache Redis) with Resilient Fallback
// ==============================================================================
const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);
const CACHE_TTL = parseInt(process.env.REDIS_TTL_SECONDS || '60', 10);

let redisClient = null;
let isRedisConnected = false;

// Metrics tracker for cache performance
const cacheMetrics = {
  hits: 0,
  misses: 0,
  flushes: 0
};

async function initRedis() {
  try {
    redisClient = redis.createClient({
      socket: {
        host: REDIS_HOST,
        port: REDIS_PORT,
        connectTimeout: 4000,
        reconnectStrategy: (retries) => {
          if (retries > 10) {
            console.warn('[Redis] Max retries reached, waiting 10s before reconnect...');
            return 10000;
          }
          return Math.min(retries * 500, 3000);
        }
      }
    });

    redisClient.on('connect', () => {
      console.log(`[Redis] Connected to Amazon ElastiCache at ${REDIS_HOST}:${REDIS_PORT}`);
      isRedisConnected = true;
    });

    redisClient.on('ready', () => {
      isRedisConnected = true;
    });

    redisClient.on('error', (err) => {
      console.warn(`[Redis] Connection warning: ${err.message}`);
      isRedisConnected = false;
    });

    redisClient.on('end', () => {
      isRedisConnected = false;
    });

    await redisClient.connect();
  } catch (err) {
    console.warn(`[Redis] Initial connection error (app will fall back to RDS): ${err.message}`);
    isRedisConnected = false;
  }
}

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Header indicating current serving host
app.use((req, res, next) => {
  res.setHeader('X-Served-By', os.hostname());
  next();
});

app.use(express.static(path.join(__dirname, 'public')));

// Database Self-Initialization Helper
async function initializeDatabase() {
  const schemaPath = path.join(__dirname, 'db', 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    try {
      console.log(`[DB] Verifying/initializing schema on Amazon RDS host: ${poolConfig.host}...`);
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      await pool.query(schemaSql);
      console.log('[DB] Schema and seed data successfully initialized on Amazon RDS.');
    } catch (err) {
      console.error('[DB] Schema initialization notice/warning:', err.message);
    }
  }
}

// ----------------------------------------------------
// Health Check Endpoint (Probes RDS & ElastiCache)
// ----------------------------------------------------
app.get('/health', async (req, res) => {
  let dbStatus = 'disconnected';
  let dbLatencyMs = null;
  let dbVersion = null;

  const dbStart = Date.now();
  try {
    const dbRes = await pool.query('SELECT NOW() as now, version() as version');
    if (dbRes.rows.length > 0) {
      dbStatus = 'connected';
      dbLatencyMs = Date.now() - dbStart;
      dbVersion = dbRes.rows[0].version ? dbRes.rows[0].version.split(' ')[1] : '15.x';
    }
  } catch (err) {
    dbStatus = `error: ${err.message}`;
  }

  let redisStatus = isRedisConnected ? 'connected' : 'disconnected';
  let redisLatencyMs = null;

  if (isRedisConnected && redisClient) {
    const rStart = Date.now();
    try {
      await redisClient.ping();
      redisLatencyMs = Date.now() - rStart;
      redisStatus = 'connected';
    } catch (err) {
      redisStatus = `error: ${err.message}`;
    }
  }

  const isHealthy = dbStatus === 'connected';

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    stage: 'Stage 4: ALB + ASG + Amazon ElastiCache (Redis) + Amazon RDS',
    application: 'ShopSphere Scaled In-Memory Caching Tier',
    version: '4.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    servingInstance: {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      totalMemMB: Math.round(os.totalmem() / 1024 / 1024),
      freeMemMB: Math.round(os.freemem() / 1024 / 1024)
    },
    database: {
      engine: 'Amazon RDS PostgreSQL',
      version: dbVersion,
      status: dbStatus,
      host: process.env.DB_HOST || '127.0.0.1',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      name: process.env.DB_NAME || 'shopspheredb',
      latencyMs: dbLatencyMs
    },
    cache: {
      engine: 'Amazon ElastiCache Redis',
      status: redisStatus,
      host: REDIS_HOST,
      port: REDIS_PORT,
      latencyMs: redisLatencyMs,
      ttlSeconds: CACHE_TTL
    }
  });
});

// ----------------------------------------------------
// Lightweight Instance Info Endpoint (for ALB testing)
// ----------------------------------------------------
app.get('/api/instance-info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    uptimeSeconds: Math.floor(process.uptime()),
    freeMemMB: Math.round(os.freemem() / 1024 / 1024),
    timestamp: new Date().toISOString(),
    servedBy: os.hostname()
  });
});

// ----------------------------------------------------
// System Info Endpoint
// ----------------------------------------------------
app.get('/api/system/info', (req, res) => {
  res.json({
    appName: 'ShopSphere Web App',
    version: '4.0.0',
    stage: 'Stage 4 - ALB + ASG + Amazon ElastiCache (Redis) + Amazon RDS',
    architecture: 'Internet -> ALB (:80) -> Target Group -> ASG EC2 Nodes -> Amazon ElastiCache (Redis :6379) & Amazon RDS (PostgreSQL :5432)',
    hostname: os.hostname(),
    nodeVersion: process.version,
    databaseHost: process.env.DB_HOST || '127.0.0.1',
    redisHost: REDIS_HOST,
    redisPort: REDIS_PORT,
    cacheMetrics
  });
});

// ----------------------------------------------------
// Cache Stats & Management APIs
// ----------------------------------------------------
app.get('/api/cache/stats', async (req, res) => {
  const totalRequests = cacheMetrics.hits + cacheMetrics.misses;
  const hitRatio = totalRequests > 0 ? ((cacheMetrics.hits / totalRequests) * 100).toFixed(1) : '0.0';

  let cachedKeys = [];
  if (isRedisConnected && redisClient) {
    try {
      cachedKeys = await redisClient.keys('shopsphere:*');
    } catch (e) {
      console.error('[Redis] Error fetching keys:', e.message);
    }
  }

  res.json({
    success: true,
    redisConnected: isRedisConnected,
    host: REDIS_HOST,
    port: REDIS_PORT,
    ttlSeconds: CACHE_TTL,
    hits: cacheMetrics.hits,
    misses: cacheMetrics.misses,
    hitRatioPercent: parseFloat(hitRatio),
    totalQueries: totalRequests,
    flushes: cacheMetrics.flushes,
    cachedKeysCount: cachedKeys.length,
    cachedKeys
  });
});

app.post('/api/cache/flush', async (req, res) => {
  if (isRedisConnected && redisClient) {
    try {
      const keys = await redisClient.keys('shopsphere:*');
      if (keys.length > 0) {
        await redisClient.del(keys);
      }
      cacheMetrics.flushes += 1;
      return res.json({
        success: true,
        message: `Flushed ${keys.length} cached keys from Amazon ElastiCache Redis`,
        flushedKeys: keys
      });
    } catch (err) {
      return res.status(500).json({ success: false, error: 'Redis flush failed: ' + err.message });
    }
  }
  res.json({ success: false, message: 'Redis not connected; no cache to flush.' });
});

// ----------------------------------------------------
// Product Catalog APIs with Cache-Aside Pattern
// ----------------------------------------------------
app.get('/api/products', async (req, res) => {
  const cacheKey = 'shopsphere:products:all';
  const start = Date.now();

  // 1. Check Redis Cache First
  if (isRedisConnected && redisClient) {
    try {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        const latencyMs = Date.now() - start;
        cacheMetrics.hits += 1;
        res.setHeader('X-Cache', 'HIT');
        res.setHeader('X-Cache-Latency', `${latencyMs}ms`);

        const products = JSON.parse(cached);
        return res.json({
          success: true,
          count: products.length,
          data: products,
          source: 'cache',
          cacheEngine: 'Amazon ElastiCache Redis',
          latencyMs,
          servedBy: os.hostname()
        });
      }
    } catch (err) {
      console.warn('[Redis] Cache read error, falling back to PostgreSQL:', err.message);
    }
  }

  // 2. Cache Miss: Query Amazon RDS PostgreSQL
  try {
    const dbStart = Date.now();
    const query = `
      SELECT p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url,
             c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.id ASC;
    `;
    const { rows } = await pool.query(query);
    const latencyMs = Date.now() - dbStart;
    cacheMetrics.misses += 1;
    res.setHeader('X-Cache', 'MISS');
    res.setHeader('X-Cache-Latency', `${latencyMs}ms`);

    // 3. Populate Redis Cache asynchronously
    if (isRedisConnected && redisClient) {
      redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(rows)).catch(err => {
        console.warn('[Redis] Cache write error:', err.message);
      });
    }

    res.json({
      success: true,
      count: rows.length,
      data: rows,
      source: 'database',
      dbEngine: 'Amazon RDS PostgreSQL',
      latencyMs,
      servedBy: os.hostname()
    });
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({ success: false, error: 'Database query failed: ' + err.message });
  }
});

app.get('/api/products/:id', async (req, res) => {
  const { id } = req.params;
  const cacheKey = `shopsphere:product:${id}`;
  const start = Date.now();

  // 1. Check Redis Cache First
  if (isRedisConnected && redisClient) {
    try {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        const latencyMs = Date.now() - start;
        cacheMetrics.hits += 1;
        res.setHeader('X-Cache', 'HIT');
        return res.json({
          success: true,
          data: JSON.parse(cached),
          source: 'cache',
          latencyMs,
          servedBy: os.hostname()
        });
      }
    } catch (err) {
      console.warn('[Redis] Cache read error:', err.message);
    }
  }

  // 2. Cache Miss: Query Amazon RDS PostgreSQL
  try {
    const dbStart = Date.now();
    const query = `
      SELECT p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url,
             c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = $1;
    `;
    const { rows } = await pool.query(query, [id]);
    const latencyMs = Date.now() - dbStart;

    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    cacheMetrics.misses += 1;
    res.setHeader('X-Cache', 'MISS');

    // 3. Populate Redis Cache
    if (isRedisConnected && redisClient) {
      redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(rows[0])).catch(err => {
        console.warn('[Redis] Cache write error:', err.message);
      });
    }

    res.json({
      success: true,
      data: rows[0],
      source: 'database',
      latencyMs,
      servedBy: os.hostname()
    });
  } catch (err) {
    console.error('Error fetching product:', err);
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

// ----------------------------------------------------
// Order Placement & Transaction APIs (ACID + Cache Invalidation)
// ----------------------------------------------------
app.get('/api/orders', async (req, res) => {
  try {
    const query = `
      SELECT o.id, o.customer_name, o.customer_email, o.shipping_address,
             o.total_amount, o.status, o.served_by_host, o.created_at,
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
    res.json({ success: true, count: rows.length, data: rows, servedBy: os.hostname() });
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
    const productIdsToInvalidate = [];

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

      productIdsToInvalidate.push(product.id);
    }

    // Insert main order record
    const orderRes = await client.query(
      `INSERT INTO orders (customer_name, customer_email, shipping_address, total_amount, status, served_by_host)
       VALUES ($1, $2, $3, $4, 'COMPLETED', $5)
       RETURNING id, created_at`,
      [customerName, customerEmail, shippingAddress, totalAmount.toFixed(2), os.hostname()]
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

    // 4. Cache Invalidation (Purge stale product catalog from Redis)
    if (isRedisConnected && redisClient) {
      const keysToDel = ['shopsphere:products:all', ...productIdsToInvalidate.map(id => `shopsphere:product:${id}`)];
      redisClient.del(keysToDel).then(() => {
        console.log(`[Redis] Cache invalidated for keys: ${keysToDel.join(', ')}`);
      }).catch(err => {
        console.warn('[Redis] Cache invalidation warning:', err.message);
      });
    }

    res.status(201).json({
      success: true,
      orderId,
      totalAmount: totalAmount.toFixed(2),
      servedByHost: os.hostname(),
      cacheInvalidated: true,
      message: 'Order created with ACID consistency & Redis cache invalidated.'
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Order creation transaction failed:', err);
    res.status(400).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

// Start Server
app.listen(PORT, async () => {
  console.log(`=======================================================`);
  console.log(`🚀 ShopSphere Stage 4 Server running on port ${PORT}`);
  console.log(`🌐 Serving Instance Hostname: ${os.hostname()}`);
  console.log(`🔗 Database Target (RDS): ${poolConfig.host}:${poolConfig.port}`);
  console.log(`⚡ In-Memory Cache Target (ElastiCache): ${REDIS_HOST}:${REDIS_PORT}`);
  console.log(`=======================================================`);
  await initializeDatabase();
  await initRedis();
});
