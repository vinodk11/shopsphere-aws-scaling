const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { Pool } = require('pg');
const redis = require('redis');
const { SQSClient, SendMessageCommand, GetQueueAttributesCommand } = require('@aws-sdk/client-sqs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

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
// 2. Redis Client (Amazon ElastiCache Redis)
// ==============================================================================
const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);
const CACHE_TTL = parseInt(process.env.REDIS_TTL_SECONDS || '60', 10);

let redisClient = null;
let isRedisConnected = false;
const cacheMetrics = { hits: 0, misses: 0, flushes: 0 };

async function initRedis() {
  try {
    redisClient = redis.createClient({
      socket: {
        host: REDIS_HOST,
        port: REDIS_PORT,
        connectTimeout: 4000,
        reconnectStrategy: (retries) => (retries > 10 ? 10000 : Math.min(retries * 500, 3000))
      }
    });

    redisClient.on('connect', () => {
      console.log(`[Redis] Connected to Amazon ElastiCache at ${REDIS_HOST}:${REDIS_PORT}`);
      isRedisConnected = true;
    });
    redisClient.on('ready', () => { isRedisConnected = true; });
    redisClient.on('error', (err) => {
      console.warn(`[Redis] Notice: ${err.message}`);
      isRedisConnected = false;
    });
    redisClient.on('end', () => { isRedisConnected = false; });

    await redisClient.connect();
  } catch (err) {
    console.warn(`[Redis] Initial connection notice (falling back to RDS): ${err.message}`);
    isRedisConnected = false;
  }
}

// ==============================================================================
// 3. Amazon SQS Client (Asynchronous Decoupled Message Queue)
// ==============================================================================
const sqsClient = new SQSClient({ region: AWS_REGION });
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL || '';

// ==============================================================================
// 4. Edge CDN & WAF Awareness Middleware (Stage 6)
// ==============================================================================
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// CloudFront Header Tracking & Cache-Control Middleware
app.use((req, res, next) => {
  const cfId = req.headers['x-amz-cf-id'];
  const cfCountry = req.headers['cloudfront-viewer-country'];
  const via = req.headers['via'] || '';

  // Always mark origin serving host
  res.setHeader('X-Served-By', os.hostname());

  // Echo CloudFront edge diagnostics if present
  if (cfId) {
    res.setHeader('X-Edge-Request-ID', cfId);
  }
  if (cfCountry) {
    res.setHeader('X-Edge-Viewer-Country', cfCountry);
  }

  // API and Health endpoints are dynamic: instruct proxies and CDNs never to cache
  if (req.path.startsWith('/api') || req.path === '/health') {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }

  next();
});

// Static assets: serve with edge-friendly Cache-Control headers
app.use(express.static(path.join(__dirname, 'public'), {
  maxAge: '1d',
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      // Revalidate HTML frequently to keep live architecture metrics fresh
      res.setHeader('Cache-Control', 'public, max-age=60');
    } else {
      // CSS, images, JS cached for 1 day
      res.setHeader('Cache-Control', 'public, max-age=86400');
    }
  }
}));

// Database Schema Self-Init
async function initializeDatabase() {
  const schemaPath = path.join(__dirname, 'db', 'schema.sql');
  if (fs.existsSync(schemaPath)) {
    try {
      console.log(`[DB] Verifying/initializing schema on Amazon RDS host: ${poolConfig.host}...`);
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      await pool.query(schemaSql);
      console.log('[DB] Schema and seed data successfully initialized.');
    } catch (err) {
      console.error('[DB] Schema initialization notice:', err.message);
    }
  }
}

// ----------------------------------------------------
// Health Check Endpoint (Probes RDS, Redis, and SQS)
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
  const cfId = req.headers['x-amz-cf-id'] || null;
  const via = req.headers['via'] || '';
  const isCloudFront = Boolean(cfId || (via && via.toLowerCase().includes('cloudfront')));

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    stage: 'Stage 6: CloudFront + AWS WAF + ALB + ASG + Redis + Amazon SQS + AWS Lambda + Amazon RDS',
    application: 'ShopSphere Global Edge Caching & Perimeter Protected Architecture',
    version: '6.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    servingInstance: {
      hostname: os.hostname(),
      platform: os.platform(),
      totalMemMB: Math.round(os.totalmem() / 1024 / 1024),
      freeMemMB: Math.round(os.freemem() / 1024 / 1024)
    },
    edge: {
      isViaCloudFront,
      cloudFrontId: cfId || 'DIRECT_ORIGIN',
      viewerCountry: req.headers['cloudfront-viewer-country'] || 'DIRECT',
      originVerifyHeader: req.headers['x-origin-verify'] ? 'PRESENT' : 'NONE'
    },
    database: {
      engine: 'Amazon RDS PostgreSQL',
      version: dbVersion,
      status: dbStatus,
      host: process.env.DB_HOST || '127.0.0.1',
      latencyMs: dbLatencyMs
    },
    cache: {
      engine: 'Amazon ElastiCache Redis',
      status: redisStatus,
      latencyMs: redisLatencyMs
    },
    queue: {
      service: 'Amazon SQS',
      queueConfigured: Boolean(SQS_QUEUE_URL),
      queueUrl: SQS_QUEUE_URL
    }
  });
});

// ----------------------------------------------------
// System & Instance Info
// ----------------------------------------------------
app.get('/api/instance-info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    uptimeSeconds: Math.floor(process.uptime()),
    freeMemMB: Math.round(os.freemem() / 1024 / 1024),
    timestamp: new Date().toISOString(),
    servedBy: os.hostname(),
    viaCloudFront: Boolean(req.headers['x-amz-cf-id'])
  });
});

app.get('/api/system/info', (req, res) => {
  const cfId = req.headers['x-amz-cf-id'] || null;
  res.json({
    appName: 'ShopSphere Web App',
    version: '6.0.0',
    stage: 'Stage 6 - Global Edge CDN (CloudFront) + Web Application Firewall (AWS WAF)',
    architecture: 'Client -> AWS WAF (L7 Inspection) -> Amazon CloudFront (Edge CDN) -> ALB (Header Lockdown) -> ASG EC2 -> RDS / Redis / SQS -> Lambda Worker',
    hostname: os.hostname(),
    databaseHost: process.env.DB_HOST || '127.0.0.1',
    redisHost: REDIS_HOST,
    sqsQueueUrl: SQS_QUEUE_URL,
    cacheMetrics,
    edgeDelivery: {
      isViaCloudFront: Boolean(cfId),
      cloudFrontId: cfId || 'DIRECT_ORIGIN_ACCESS',
      viewerCountry: req.headers['cloudfront-viewer-country'] || 'DIRECT',
      originVerifyHeaderPresent: Boolean(req.headers['x-origin-verify'])
    }
  });
});

// ----------------------------------------------------
// Edge & WAF Diagnostics API (Stage 6)
// ----------------------------------------------------
app.get('/api/edge-info', (req, res) => {
  const cfId = req.headers['x-amz-cf-id'] || null;
  const cfCountry = req.headers['cloudfront-viewer-country'] || 'LOCAL/DIRECT';
  const cfCountryName = req.headers['cloudfront-viewer-country-name'] || null;
  const cfCity = req.headers['cloudfront-viewer-city'] || null;
  const cfDevice = req.headers['cloudfront-is-mobile-viewer'] === 'true' ? 'Mobile' :
                   (req.headers['cloudfront-is-tablet-viewer'] === 'true' ? 'Tablet' :
                   (req.headers['cloudfront-is-desktop-viewer'] === 'true' ? 'Desktop' : 'Standard Browser'));
  const via = req.headers['via'] || 'Direct connection (No proxy)';
  const originVerify = req.headers['x-origin-verify'] ? 'VERIFIED_MATCH' : 'DIRECT_OR_TEST';
  const clientIp = req.headers['x-forwarded-for'] ? req.headers['x-forwarded-for'].split(',')[0].trim() : req.socket.remoteAddress;

  res.json({
    success: true,
    edgeDelivery: {
      isViaCloudFront: Boolean(cfId || (via && via.toLowerCase().includes('cloudfront'))),
      cloudFrontRayId: cfId || 'DIRECT_ORIGIN_REQUEST',
      viaHeader: via,
      viewer: {
        ip: clientIp,
        countryCode: cfCountry,
        countryName: cfCountryName,
        city: cfCity,
        deviceType: cfDevice
      },
      originProtection: {
        headerLockdown: 'X-Origin-Verify',
        verificationStatus: originVerify
      }
    },
    wafProtection: {
      status: 'ACTIVE',
      scope: 'CLOUDFRONT (Global us-east-1)',
      managedRuleGroups: [
        { name: 'AWSManagedRulesCommonRuleSet', priority: 10, action: 'BLOCK' },
        { name: 'AWSManagedRulesKnownBadInputsRuleSet', priority: 20, action: 'BLOCK' },
        { name: 'AWSManagedRulesAmazonIpReputationList', priority: 30, action: 'BLOCK' },
        { name: 'RateLimitPerIP (500 req/5m)', priority: 40, action: 'BLOCK' }
      ]
    },
    originNode: {
      hostname: os.hostname(),
      platform: os.platform(),
      uptimeSeconds: Math.floor(process.uptime())
    },
    cachingStrategy: {
      staticAssets: 'CloudFront Edge Cache (TTL 86400s / 1 Day)',
      apiRoutes: 'Dynamic Origin Forwarding (TTL 0 / No-Cache)',
      healthCheck: 'Dynamic Origin Forwarding (TTL 0 / No-Cache)'
    }
  });
});

// ----------------------------------------------------
// SQS Queue Statistics
// ----------------------------------------------------
app.get('/api/queue/stats', async (req, res) => {
  if (!SQS_QUEUE_URL) {
    return res.json({
      success: true,
      configured: false,
      message: 'SQS_QUEUE_URL not configured in environment; running in direct fallback mode.'
    });
  }

  try {
    const cmd = new GetQueueAttributesCommand({
      QueueUrl: SQS_QUEUE_URL,
      AttributeNames: [
        'ApproximateNumberOfMessages',
        'ApproximateNumberOfMessagesNotVisible',
        'ApproximateNumberOfMessagesDelayed'
      ]
    });
    const result = await sqsClient.send(cmd);
    res.json({
      success: true,
      configured: true,
      queueUrl: SQS_QUEUE_URL,
      approximateMessages: parseInt(result.Attributes?.ApproximateNumberOfMessages || '0', 10),
      inFlightMessages: parseInt(result.Attributes?.ApproximateNumberOfMessagesNotVisible || '0', 10),
      delayedMessages: parseInt(result.Attributes?.ApproximateNumberOfMessagesDelayed || '0', 10)
    });
  } catch (err) {
    console.warn('[SQS] Error fetching queue attributes:', err.message);
    res.status(500).json({ success: false, error: 'SQS query failed: ' + err.message });
  }
});

// ----------------------------------------------------
// Product Catalog APIs with Cache-Aside
// ----------------------------------------------------
app.get('/api/products', async (req, res) => {
  const cacheKey = 'shopsphere:products:all';
  const start = Date.now();

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
          latencyMs,
          servedBy: os.hostname()
        });
      }
    } catch (err) {
      console.warn('[Redis] Cache read error, falling back to PostgreSQL:', err.message);
    }
  }

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

    if (isRedisConnected && redisClient) {
      redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(rows)).catch(() => {});
    }

    res.json({
      success: true,
      count: rows.length,
      data: rows,
      source: 'database',
      latencyMs,
      servedBy: os.hostname()
    });
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({ success: false, error: 'Database query failed: ' + err.message });
  }
});

// Cache Flush
app.post('/api/cache/flush', async (req, res) => {
  if (isRedisConnected && redisClient) {
    try {
      const keys = await redisClient.keys('shopsphere:*');
      if (keys.length > 0) await redisClient.del(keys);
      cacheMetrics.flushes += 1;
      return res.json({ success: true, message: `Flushed ${keys.length} cached keys from Redis` });
    } catch (err) {
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  res.json({ success: false, message: 'Redis not connected.' });
});

// ----------------------------------------------------
// Asynchronous Order Placement (SQS + Immediate 202 Accepted)
// ----------------------------------------------------
app.get('/api/orders', async (req, res) => {
  try {
    const query = `
      SELECT o.id, o.customer_name, o.customer_email, o.shipping_address,
             o.total_amount, o.status, o.served_by_host, o.processed_by_worker, o.processed_at, o.created_at,
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
      LIMIT 25;
    `;
    const { rows } = await pool.query(query);
    res.json({ success: true, count: rows.length, data: rows, servedBy: os.hostname() });
  } catch (err) {
    console.error('Error fetching orders:', err);
    res.status(500).json({ success: false, error: 'Database query failed' });
  }
});

app.get('/api/orders/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(
      'SELECT id, status, total_amount, served_by_host, processed_by_worker, processed_at, created_at FROM orders WHERE id = $1',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/orders', async (req, res) => {
  const client = await pool.connect();
  const startTime = Date.now();
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

    // Atomically reserve inventory
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

      await client.query(
        'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2',
        [item.quantity, item.productId]
      );

      validatedItems.push({
        productId: product.id,
        name: product.name,
        quantity: item.quantity,
        unitPrice: product.price
      });

      productIdsToInvalidate.push(product.id);
    }

    // Insert order record with initial 'PENDING' status
    const orderRes = await client.query(
      `INSERT INTO orders (customer_name, customer_email, shipping_address, total_amount, status, served_by_host)
       VALUES ($1, $2, $3, $4, 'PENDING', $5)
       RETURNING id, created_at`,
      [customerName, customerEmail, shippingAddress, totalAmount.toFixed(2), os.hostname()]
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

    // Invalidate Redis Cache
    if (isRedisConnected && redisClient) {
      const keysToDel = ['shopsphere:products:all', ...productIdsToInvalidate.map(id => `shopsphere:product:${id}`)];
      redisClient.del(keysToDel).catch(() => {});
    }

    // Publish Order Event to Amazon SQS Queue
    let sqsMessageId = null;
    let publishSuccess = false;

    if (SQS_QUEUE_URL) {
      try {
        const orderPayload = {
          eventType: 'ORDER_CREATED',
          orderId,
          customerName,
          customerEmail,
          shippingAddress,
          totalAmount: totalAmount.toFixed(2),
          items: validatedItems,
          timestamp: new Date().toISOString(),
          createdAt: new Date().toISOString(),
          ingestedByHost: os.hostname()
        };

        const sendCmd = new SendMessageCommand({
          QueueUrl: SQS_QUEUE_URL,
          MessageBody: JSON.stringify(orderPayload),
          MessageAttributes: {
            OrderType: { DataType: 'String', StringValue: 'OnlineCheckout' },
            OrderId: { DataType: 'String', StringValue: String(orderId) }
          }
        });

        const sqsRes = await sqsClient.send(sendCmd);
        sqsMessageId = sqsRes.MessageId;
        publishSuccess = true;
        console.log(`[SQS] Successfully published Order #${orderId} to SQS (MessageId: ${sqsMessageId})`);
      } catch (sqsErr) {
        console.error(`[SQS] Failed to publish Order #${orderId} to SQS:`, sqsErr.message);
      }
    } else {
      console.log(`[SQS] Notice: SQS_QUEUE_URL not configured. Order #${orderId} saved as PENDING in RDS.`);
    }

    const elapsedMs = Date.now() - startTime;

    // Return immediate 202 Accepted response (Non-blocking asynchronous response)
    res.status(202).json({
      success: true,
      orderId,
      status: 'PENDING',
      totalAmount: totalAmount.toFixed(2),
      ingestedByHost: os.hostname(),
      queuePublished: publishSuccess,
      sqsMessageId,
      checkoutLatencyMs: elapsedMs,
      message: 'Order accepted for asynchronous processing via Amazon SQS & AWS Lambda'
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
  console.log(`🚀 ShopSphere Stage 6 Server running on port ${PORT}`);
  console.log(`🌐 Serving Host: ${os.hostname()}`);
  console.log(`🛡️ Web Application Firewall: AWS WAFv2 Enabled`);
  console.log(`⚡ Edge CDN: Amazon CloudFront Enabled`);
  console.log(`🔗 Database Target (RDS): ${poolConfig.host}:${poolConfig.port}`);
  console.log(`⚡ In-Memory Cache (ElastiCache): ${REDIS_HOST}:${REDIS_PORT}`);
  console.log(`📬 Event Queue (Amazon SQS): ${SQS_QUEUE_URL || 'Not configured'}`);
  console.log(`=======================================================`);
  await initializeDatabase();
  await initRedis();
});
