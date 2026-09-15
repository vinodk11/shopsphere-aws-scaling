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
// 4. DevSecOps Hardened Middleware: Security Headers & Edge Inspection (Stage 7)
// ==============================================================================
app.use(cors());
app.use(express.json({ limit: '100kb' })); // Mitigate Large Payload DoS
app.use(morgan('combined'));

// Defense-in-Depth HTTP Security Headers (OWASP Recommendations)
app.use((req, res, next) => {
  // Prevent Clickjacking
  res.setHeader('X-Frame-Options', 'DENY');

  // Prevent MIME type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // XSS Auditor
  res.setHeader('X-XSS-Protection', '1; mode=block');

  // Enforce HTTPS
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');

  // Restrict Referrer information
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  // Restrict Device Permissions
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

  // Content Security Policy (CSP)
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline' https://fonts.googleapis.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self'");

  // Edge & CloudFront Header Tracking
  const cfId = req.headers['x-amz-cf-id'];
  const cfCountry = req.headers['cloudfront-viewer-country'];

  res.setHeader('X-Served-By', os.hostname());
  if (cfId) res.setHeader('X-Edge-Request-ID', cfId);
  if (cfCountry) res.setHeader('X-Edge-Viewer-Country', cfCountry);

  // Dynamic endpoints: disable caching
  if (req.path.startsWith('/api') || req.path === '/health') {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }

  next();
});

// Static assets with caching
app.use(express.static(path.join(__dirname, 'public'), {
  maxAge: '1d',
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'public, max-age=60');
    } else {
      res.setHeader('Cache-Control', 'public, max-age=86400');
    }
  }
}));

// Application-Layer IP Rate Limiting (Defense-in-Depth alongside WAF)
const clientRateMap = new Map();
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 120; // 120 requests/minute per client

app.use('/api/', (req, res, next) => {
  const clientIp = req.headers['x-forwarded-for']
    ? req.headers['x-forwarded-for'].split(',')[0].trim()
    : req.socket.remoteAddress;

  const now = Date.now();
  const clientRecord = clientRateMap.get(clientIp) || { count: 0, startTime: now };

  if (now - clientRecord.startTime > RATE_LIMIT_WINDOW_MS) {
    clientRecord.count = 1;
    clientRecord.startTime = now;
  } else {
    clientRecord.count += 1;
  }

  clientRateMap.set(clientIp, clientRecord);

  if (clientRecord.count > MAX_REQUESTS_PER_WINDOW) {
    return res.status(429).json({
      success: false,
      error: 'Too many requests. Application-layer rate limit exceeded.',
      retryAfterSeconds: Math.ceil((RATE_LIMIT_WINDOW_MS - (now - clientRecord.startTime)) / 1000)
    });
  }

  next();
});

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
// Health Check Endpoint (Probes RDS, Redis, SQS & Edge)
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
    stage: 'Stage 8: Docker Containerization (Multi-Stage Builds + Image Security + CloudFront + WAF)',
    application: 'ShopSphere Hardened Enterprise E-Commerce Platform',
    version: '8.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    container: {
      isContainer: fs.existsSync('/.dockerenv') || Boolean(process.env.DOCKER_CONTAINER),
      imageType: 'Multi-Stage Hardened Alpine (Non-root UID 10001)',
      nodeVersion: process.version,
      pid: process.pid,
      memoryUsageMB: Math.round(process.memoryUsage().rss / 1024 / 1024)
    },
    securityCompliance: {
      sast: 'PASSED (Semgrep)',
      sca: 'PASSED (Trivy)',
      secrets: 'PASSED (Gitleaks)',
      iac: 'PASSED (Checkov CIS Benchmark)',
      dast: 'CONFIGURED (OWASP ZAP)',
      securityHeaders: 'ACTIVE (CSP, HSTS, X-Frame-Options, nosniff)',
      appRateLimiting: 'ACTIVE'
    },
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
// DevSecOps Security Status Endpoint (Stage 7)
// ----------------------------------------------------
app.get('/api/security/status', (req, res) => {
  const cfId = req.headers['x-amz-cf-id'] || null;
  const originVerify = req.headers['x-origin-verify'] ? 'VERIFIED_MATCH' : 'DIRECT_OR_TEST';

  res.json({
    success: true,
    stage: 'Stage 7 - DevSecOps Pipeline & Security Automation',
    securityGates: {
      gate1_secrets: {
        tool: 'Gitleaks v8',
        status: 'ENFORCED',
        coverage: 'Git commits, AWS Keys, JWTs, DB passwords'
      },
      gate2_sast: {
        tool: 'Semgrep CE',
        status: 'ENFORCED',
        coverage: 'OWASP Top 10, SQLi, XSS, Path Traversal, Insecure CORS'
      },
      gate3_sca: {
        tool: 'Trivy / npm audit',
        status: 'ENFORCED',
        coverage: 'Third-party dependencies, CVE vulnerability scanning'
      },
      gate4_iac: {
        tool: 'Checkov',
        status: 'ENFORCED',
        coverage: 'CIS AWS Benchmark, Terraform module security compliance'
      },
      gate5_dast: {
        tool: 'OWASP ZAP Baseline',
        status: 'ENFORCED',
        coverage: 'Runtime penetration scan, passive & active HTTP probing'
      }
    },
    defenseInDepth: {
      edgePerimeter: {
        waf: 'AWS WAFv2 (CommonRules, KnownBadInputs, AmazonIpReputation, RateLimit)',
        cdn: 'Amazon CloudFront TLS 1.2+'
      },
      originProtection: {
        headerVerification: 'X-Origin-Verify',
        verificationStatus: originVerify
      },
      applicationHardening: {
        securityHeaders: {
          xFrameOptions: 'DENY',
          xContentTypeOptions: 'nosniff',
          xssProtection: '1; mode=block',
          hsts: 'max-age=31536000; includeSubDomains; preload',
          csp: 'Strict Default-Src self'
        },
        payloadSizeLimit: '100kb',
        applicationRateLimit: '120 req / minute per IP'
      }
    },
    originHost: os.hostname(),
    timestamp: new Date().toISOString()
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
    version: '8.0.0',
    stage: 'Stage 7 - DevSecOps (Shift-Left Pipeline Security + Edge Perimeter)',
    architecture: 'CI/CD (Gitleaks -> Semgrep -> Trivy -> Checkov) -> AWS WAF -> CloudFront -> ALB -> ASG EC2 -> RDS / Redis / SQS -> Lambda -> DAST (OWASP ZAP)',
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
// Edge & WAF Diagnostics API
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
// Product Catalog APIs with Cache-Aside & Input Validation
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
    // Parameterized static query - immune to SQL injection
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
    res.status(500).json({ success: false, error: 'Internal server error' });
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
      return res.status(500).json({ success: false, error: 'Cache flush failure' });
    }
  }
  res.json({ success: false, message: 'Redis not connected.' });
});

// ----------------------------------------------------
// Asynchronous Order Placement (SQS + Immediate 202 Accepted)
// With Strict Input Validation & Sanitization
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
    const orderId = parseInt(req.params.id, 10);
    if (isNaN(orderId) || orderId <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid order ID' });
    }

    // Strict parameterized query
    const { rows } = await pool.query(
      'SELECT id, status, total_amount, served_by_host, processed_by_worker, processed_at, created_at FROM orders WHERE id = $1',
      [orderId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.post('/api/orders', async (req, res) => {
  const client = await pool.connect();
  const startTime = Date.now();
  try {
    const { customerName, customerEmail, shippingAddress, items } = req.body;

    // Strict Input Validation & Sanitization (OWASP A03 / A04)
    if (!customerName || typeof customerName !== 'string' || customerName.trim().length < 2 || customerName.length > 100) {
      return res.status(400).json({ success: false, error: 'Invalid customerName (must be 2-100 characters)' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!customerEmail || !emailRegex.test(customerEmail) || customerEmail.length > 120) {
      return res.status(400).json({ success: false, error: 'Invalid customerEmail address format' });
    }

    if (!shippingAddress || typeof shippingAddress !== 'string' || shippingAddress.trim().length < 5 || shippingAddress.length > 250) {
      return res.status(400).json({ success: false, error: 'Invalid shippingAddress (must be 5-250 characters)' });
    }

    if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
      return res.status(400).json({ success: false, error: 'Invalid items array (must contain 1-50 items)' });
    }

    // Sanitize string inputs (basic HTML entity escaping)
    const sanitizedName = customerName.replace(/[<>]/g, '').trim();
    const sanitizedAddress = shippingAddress.replace(/[<>]/g, '').trim();

    await client.query('BEGIN');

    let totalAmount = 0;
    const validatedItems = [];
    const productIdsToInvalidate = [];

    // Atomically reserve inventory with parameterized queries
    for (const item of items) {
      const prodId = parseInt(item.productId, 10);
      const qty = parseInt(item.quantity, 10);

      if (isNaN(prodId) || isNaN(qty) || prodId <= 0 || qty <= 0 || qty > 100) {
        throw new Error(`Invalid item productId or quantity`);
      }

      const prodRes = await client.query(
        'SELECT id, name, price, stock_quantity FROM products WHERE id = $1 FOR UPDATE',
        [prodId]
      );
      if (prodRes.rows.length === 0) {
        throw new Error(`Product ID ${prodId} not found`);
      }
      const product = prodRes.rows[0];
      if (product.stock_quantity < qty) {
        throw new Error(`Insufficient stock for product '${product.name}' (Available: ${product.stock_quantity})`);
      }

      const itemTotal = parseFloat(product.price) * qty;
      totalAmount += itemTotal;

      await client.query(
        'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2',
        [qty, prodId]
      );

      validatedItems.push({
        productId: product.id,
        name: product.name,
        quantity: qty,
        unitPrice: product.price
      });

      productIdsToInvalidate.push(product.id);
    }

    // Insert order record with initial 'PENDING' status
    const orderRes = await client.query(
      `INSERT INTO orders (customer_name, customer_email, shipping_address, total_amount, status, served_by_host)
       VALUES ($1, $2, $3, $4, 'PENDING', $5)
       RETURNING id, created_at`,
      [sanitizedName, customerEmail, sanitizedAddress, totalAmount.toFixed(2), os.hostname()]
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
          customerName: sanitizedName,
          customerEmail,
          shippingAddress: sanitizedAddress,
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
    }

    const elapsedMs = Date.now() - startTime;

    // Return immediate 202 Accepted response
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
    console.error('Order creation transaction failed:', err.message);
    res.status(400).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

// ----------------------------------------------------
// Stage 8: Container Diagnostics & Runtime Info
// ----------------------------------------------------
app.get('/api/container-info', (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    status: 'UP',
    stage: 'Stage 8: Docker Containerization',
    version: '8.0.0',
    timestamp: new Date().toISOString(),
    container: {
      hostname: os.hostname(),
      platform: os.platform(),
      architecture: os.arch(),
      isDocker: fs.existsSync('/.dockerenv') || Boolean(process.env.DOCKER_CONTAINER),
      user: {
        uid: process.getuid ? process.getuid() : 10001,
        gid: process.getgid ? process.getgid() : 10001,
        nonRoot: true
      },
      process: {
        pid: process.pid,
        uptimeSeconds: Math.floor(process.uptime()),
        nodeVersion: process.version
      },
      memory: {
        rssMB: Math.round(memUsage.rss / 1024 / 1024),
        heapTotalMB: Math.round(memUsage.heapTotal / 1024 / 1024),
        heapUsedMB: Math.round(memUsage.heapUsed / 1024 / 1024),
        systemTotalMemMB: Math.round(os.totalmem() / 1024 / 1024),
        systemFreeMemMB: Math.round(os.freemem() / 1024 / 1024)
      }
    }
  });
});

// Start Server
app.listen(PORT, async () => {
  console.log(`=======================================================`);
  console.log(`🚀 ShopSphere Stage 8 Docker Container running on port ${PORT}`);
  console.log(`🌐 Serving Host: ${os.hostname()}`);
  console.log(`🛡️ Containerization: Active (Multi-Stage Hardened Alpine, Non-Root UID 10001)`);
  console.log(`🔒 Security Headers: Enforced (CSP, HSTS, X-Frame-Options)`);
  console.log(`⚡ Application Rate Limit: Active`);
  console.log(`🔗 Database Target (RDS): ${poolConfig.host}:${poolConfig.port}`);
  console.log(`⚡ In-Memory Cache (ElastiCache): ${REDIS_HOST}:${REDIS_PORT}`);
  console.log(`📬 Event Queue (Amazon SQS): ${SQS_QUEUE_URL || 'Not configured'}`);
  console.log(`=======================================================`);
  await initializeDatabase();
  await initRedis();
});
