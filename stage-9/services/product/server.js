// ==============================================================================
// ShopSphere Microservice: Product Service (Stage 9 EKS)
// Handles Product Catalog operations with PostgreSQL & ElastiCache Redis
// ==============================================================================
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Pool } = require('pg');
const redis = require('redis');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8081;

app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(morgan('combined'));

// Database Pool Configuration
const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'shopsphere',
  user: process.env.DB_USER || 'shopsphere_user',
  password: process.env.DB_PASSWORD || 'password',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 3000,
  ssl: (process.env.DB_SSL === 'true' || process.env.NODE_ENV === 'production') ? { rejectUnauthorized: false } : false
});

// Redis Client Configuration
let redisClient = null;
let isRedisConnected = false;

if (process.env.REDIS_HOST) {
  redisClient = redis.createClient({
    socket: {
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379', 10),
      connectTimeout: 3000
    }
  });

  redisClient.on('connect', () => {
    isRedisConnected = true;
    console.log(`[ProductService] Connected to Redis at ${process.env.REDIS_HOST}`);
  });

  redisClient.on('error', (err) => {
    isRedisConnected = false;
    console.warn(`[ProductService] Redis connection warning: ${err.message}`);
  });

  redisClient.connect().catch((err) => {
    console.warn(`[ProductService] Redis init connection failed: ${err.message}`);
  });
}

// ------------------------------------------------------------------------------
// Health Check Endpoint (Required by EKS Probes and ALB Target Group)
// ------------------------------------------------------------------------------
app.get('/health', async (req, res) => {
  let dbStatus = 'disconnected';
  let dbLatencyMs = null;

  const dbStart = Date.now();
  try {
    const dbRes = await pool.query('SELECT 1 as healthy');
    if (dbRes.rows.length > 0) {
      dbStatus = 'connected';
      dbLatencyMs = Date.now() - dbStart;
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
    service: 'shopsphere-product-service',
    version: '9.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: {
      status: dbStatus,
      latencyMs: dbLatencyMs
    },
    cache: {
      status: redisStatus,
      latencyMs: redisLatencyMs
    }
  });
});

// ------------------------------------------------------------------------------
// Product Catalog Endpoints
// ------------------------------------------------------------------------------
const DEFAULT_PRODUCTS = [
  { id: 1, name: "CloudBeats ANC Wireless Headphones", price: 199.99, category: "Electronics", in_stock: 45 },
  { id: 2, name: "VaporFly Ergonomic Mechanical Keyboard", price: 129.99, category: "Accessories", in_stock: 80 },
  { id: 3, name: "AeroShield 4K HDR Monitor 27-inch", price: 349.99, category: "Electronics", in_stock: 25 },
  { id: 4, name: "HyperCharge 100W USB-C GaN Charger", price: 49.99, category: "Accessories", in_stock: 150 },
  { id: 5, name: "Nimbus Pro Ultra-Light Wireless Mouse", price: 79.99, category: "Accessories", in_stock: 95 },
  { id: 6, name: "QuantumDrive 2TB NVMe PCIe 4.0 SSD", price: 169.99, category: "Storage", in_stock: 60 }
];

app.get(['/api/products', '/products'], async (req, res) => {
  const cacheKey = 'shopsphere:products:all';

  // Try Redis cache first
  if (isRedisConnected && redisClient) {
    try {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        return res.json({
          success: true,
          source: 'cache-redis',
          count: JSON.parse(cached).length,
          data: JSON.parse(cached)
        });
      }
    } catch (cacheErr) {
      console.warn(`[ProductService] Redis read failed: ${cacheErr.message}`);
    }
  }

  // Fallback to PostgreSQL database
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY id ASC');
    const products = result.rows.length > 0 ? result.rows : DEFAULT_PRODUCTS;

    // Cache in Redis for 60 seconds
    if (isRedisConnected && redisClient) {
      redisClient.setEx(cacheKey, 60, JSON.stringify(products)).catch(() => {});
    }

    res.json({
      success: true,
      source: result.rows.length > 0 ? 'database-rds' : 'fallback-static',
      count: products.length,
      data: products
    });
  } catch (dbErr) {
    // Graceful fallback to static list if table not yet seeded
    res.json({
      success: true,
      source: 'fallback-static',
      count: DEFAULT_PRODUCTS.length,
      data: DEFAULT_PRODUCTS
    });
  }
});

app.get(['/api/products/:id', '/products/:id'], async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) {
    return res.status(400).json({ success: false, message: 'Invalid product ID' });
  }

  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
    if (result.rows.length > 0) {
      return res.json({ success: true, data: result.rows[0] });
    }
  } catch (err) {
    // Continue to fallback
  }

  const fallback = DEFAULT_PRODUCTS.find(p => p.id === id);
  if (fallback) {
    return res.json({ success: true, data: fallback });
  }

  res.status(404).json({ success: false, message: 'Product not found' });
});

// Cache Flush Endpoint
app.post(['/api/products/cache/flush', '/products/cache/flush'], async (req, res) => {
  if (isRedisConnected && redisClient) {
    try {
      await redisClient.del('shopsphere:products:all');
      return res.json({ success: true, message: 'Product cache flushed successfully' });
    } catch (err) {
      return res.status(500).json({ success: false, message: err.message });
    }
  }
  res.json({ success: true, message: 'Redis cache not connected; skipped' });
});

app.listen(PORT, () => {
  console.log(`[ProductService] Microservice listening on port ${PORT}`);
});
