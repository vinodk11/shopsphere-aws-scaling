// ==============================================================================
// ShopSphere Microservice: User Service (Stage 9 EKS)
// Handles User Profiles and Authentication with PostgreSQL
// ==============================================================================
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8083;

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
  connectionTimeoutMillis: 3000
});

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

  const isHealthy = dbStatus === 'connected';

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    service: 'shopsphere-user-service',
    version: '9.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: {
      status: dbStatus,
      latencyMs: dbLatencyMs
    }
  });
});

// ------------------------------------------------------------------------------
// User Endpoints
// ------------------------------------------------------------------------------
app.get(['/api/users/profile', '/users/profile'], (req, res) => {
  res.json({
    success: true,
    service: 'user-service',
    user: {
      id: 101,
      username: "cloud-shopper",
      email: "shopper@shopsphere.io",
      role: "customer",
      memberSince: "2026-01-01",
      tier: "Platinum Cloud Member"
    }
  });
});

app.post(['/api/users/login', '/users/login'], (req, res) => {
  const { username } = req.body;
  res.json({
    success: true,
    service: 'user-service',
    message: `Authentication successful for ${username || 'demo-user'}`,
    token: `jwt-simulated-token-${Date.now()}`
  });
});

app.listen(PORT, () => {
  console.log(`[UserService] Microservice listening on port ${PORT}`);
});
