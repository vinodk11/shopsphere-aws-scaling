// ==============================================================================
// ShopSphere Microservice: Product Service (Stage 10 GitOps + Argo CD)
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
  database: process.env.DB_NAME || 'shopspheredb',
  user: process.env.DB_USER || 'shopsphere_user',
  password: process.env.DB_PASSWORD || 'ShopSphere2026SecurePass!',
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
// Comprehensive 16-Product Catalog (Stage 10 Enhanced Product Lineup)
// ------------------------------------------------------------------------------
const DEFAULT_PRODUCTS = [
  {
    id: 1,
    category_id: 1,
    category_name: "Audio & Electronics",
    name: "CloudBeats ANC Wireless Headphones",
    description: "Active noise cancelling wireless headphones with 40-hour battery life and spatial audio.",
    price: 199.99,
    stock_quantity: 45,
    image_url: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 2,
    category_id: 2,
    category_name: "Wearables",
    name: "ShopSphere Apex Smart Watch",
    description: "AMOLED display, continuous ECG & SpO2 tracking, 7-day battery, and 5ATM water resistance.",
    price: 249.99,
    stock_quantity: 30,
    image_url: "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 3,
    category_id: 1,
    category_name: "Audio & Electronics",
    name: "UltraHD 4K Action Camera",
    description: "Compact waterproof 4K/60fps camera with 6-axis gyro stabilization and dual screens.",
    price: 129.99,
    stock_quantity: 25,
    image_url: "https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 4,
    category_id: 3,
    category_name: "Smart Home",
    name: "Aurora Smart RGB Desk Lamp",
    description: "Voice-controlled ambient lighting with custom gradients, timer routines, and adaptive brightness.",
    price: 49.99,
    stock_quantity: 60,
    image_url: "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 5,
    category_id: 4,
    category_name: "Computer Peripherals",
    name: "CyberDeck RGB Mechanical Keyboard",
    description: "Hot-swappable tactile mechanical switches, PBT keycaps, and aircraft-grade aluminum chassis.",
    price: 89.99,
    stock_quantity: 40,
    image_url: "https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 6,
    category_id: 1,
    category_name: "Audio & Electronics",
    name: "HyperCharge 20000mAh Power Bank",
    description: "65W USB-C Power Delivery fast-charging power bank for laptops, tablets, and smartphones.",
    price: 39.99,
    stock_quantity: 75,
    image_url: "https://images.unsplash.com/photo-1609592426507-da665123d537?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 7,
    category_id: 4,
    category_name: "Computer Peripherals",
    name: "QuantumDrive 2TB NVMe Gen4 SSD",
    description: "Ultra-fast 7,400 MB/s read speeds, PCIe 4.0 interface with integrated graphite thermal heatsink.",
    price: 179.99,
    stock_quantity: 50,
    image_url: "https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 8,
    category_id: 4,
    category_name: "Computer Peripherals",
    name: "AeroShield 27-inch 4K HDR Monitor",
    description: "IPS panel with 99% DCI-P3 color gamut, USB-C 90W single-cable docking, and ergonomic stand.",
    price: 389.99,
    stock_quantity: 20,
    image_url: "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 9,
    category_id: 4,
    category_name: "Computer Peripherals",
    name: "Nimbus Pro Ultra-Light Wireless Mouse",
    description: "58-gram honeycomb ultralight design, 26,000 DPI optical sensor, and low-latency 2.4GHz wireless.",
    price: 69.99,
    stock_quantity: 90,
    image_url: "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 10,
    category_id: 5,
    category_name: "Developer Gear",
    name: "OctaCore Edge AI Neural Compute Stick",
    description: "Accelerated tensor processing unit (TPU) over USB 3.2 for edge machine learning inferences.",
    price: 119.99,
    stock_quantity: 35,
    image_url: "https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 11,
    category_id: 6,
    category_name: "Cloud & Networking",
    name: "CloudForge 10Gbps Managed SFP+ Switch",
    description: "8-port Layer-2+ enterprise gigabit switch with two 10G SFP+ uplink ports and silent fanless cooling.",
    price: 299.99,
    stock_quantity: 15,
    image_url: "https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 12,
    category_id: 4,
    category_name: "Computer Peripherals",
    name: "VaporLock Ergonomic Aluminum Laptop Stand",
    description: "Precision CNC anodized aluminum stand with dual-hinge 360-degree rotation and heat dissipation.",
    price: 44.99,
    stock_quantity: 110,
    image_url: "https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 13,
    category_id: 3,
    category_name: "Smart Home",
    name: "Sentinel Smart Security Camera Hub",
    description: "2K HDR wireless security camera with on-device human detection, color night vision, and local storage.",
    price: 89.99,
    stock_quantity: 40,
    image_url: "https://images.unsplash.com/photo-1557324232-b8917d3c3dcb?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 14,
    category_id: 1,
    category_name: "Audio & Electronics",
    name: "EchoPulse Hi-Res Studio Monitors (Pair)",
    description: "Bi-amped nearfield reference studio monitors with custom silk dome tweeters and balanced XLR inputs.",
    price: 279.99,
    stock_quantity: 18,
    image_url: "https://images.unsplash.com/photo-1545454675-3531b543be5d?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 15,
    category_id: 1,
    category_name: "Audio & Electronics",
    name: "MagnaCharge 3-in-1 Wireless Charging Pad",
    description: "Fast magnetic wireless charging station for phone, smartwatch, and earbuds with LED status indicators.",
    price: 59.99,
    stock_quantity: 85,
    image_url: "https://images.unsplash.com/photo-1622445262464-84b1456045b6?w=500&auto=format&fit=crop&q=60"
  },
  {
    id: 16,
    category_id: 5,
    category_name: "Developer Gear",
    name: "KubeKey FIDO2 Hardware Security Key",
    description: "NFC + USB-C hardware authenticator for passwordless multi-factor authentication and cloud IAM access.",
    price: 54.99,
    stock_quantity: 120,
    image_url: "https://images.unsplash.com/photo-1563770660941-20978e870e26?w=500&auto=format&fit=crop&q=60"
  }
];

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
    version: '10.0.0',
    stage: 'Stage 10: GitOps & Argo CD',
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
app.get(['/api/products', '/products'], async (req, res) => {
  const cacheKey = 'shopsphere:products:all:v10';

  // Try Redis cache first
  if (isRedisConnected && redisClient) {
    try {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        const parsed = JSON.parse(cached);
        return res.json({
          success: true,
          source: 'cache-redis',
          count: parsed.length,
          data: parsed
        });
      }
    } catch (cacheErr) {
      console.warn(`[ProductService] Redis read failed: ${cacheErr.message}`);
    }
  }

  // Fallback to PostgreSQL database
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY id ASC');
    const products = result.rows.length >= 6 ? result.rows : DEFAULT_PRODUCTS;

    // Cache in Redis for 60 seconds
    if (isRedisConnected && redisClient) {
      redisClient.setEx(cacheKey, 60, JSON.stringify(products)).catch(() => {});
    }

    res.json({
      success: true,
      source: result.rows.length >= 6 ? 'database-rds' : 'fallback-static',
      count: products.length,
      data: products
    });
  } catch (dbErr) {
    // Graceful fallback to static list of 16 products
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
      await redisClient.del('shopsphere:products:all:v10');
      return res.json({ success: true, message: 'Product cache flushed successfully' });
    } catch (err) {
      return res.status(500).json({ success: false, message: err.message });
    }
  }
  res.json({ success: true, message: 'Redis cache not connected; skipped' });
});

app.listen(PORT, () => {
  console.log(`[ProductService] Stage 10 Product Microservice listening on port ${PORT}`);
});
