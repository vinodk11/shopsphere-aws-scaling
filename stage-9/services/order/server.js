// ==============================================================================
// ShopSphere Microservice: Order Service (Stage 9 EKS)
// Handles Order Placement, PostgreSQL Storage, and SQS Asynchronous Dispatch
// ==============================================================================
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Pool } = require('pg');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8082;
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL || '';

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

// AWS SQS Client (Uses IRSA token mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token)
const sqsClient = new SQSClient({ region: AWS_REGION });

// Ensure orders table exists
async function initDb() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        customer_name VARCHAR(100) NOT NULL,
        customer_email VARCHAR(100) NOT NULL,
        total_amount NUMERIC(10, 2) NOT NULL,
        status VARCHAR(50) DEFAULT 'PENDING',
        items JSONB,
        sqs_message_id VARCHAR(100),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('[OrderService] Orders table verified in PostgreSQL');
  } catch (err) {
    console.warn(`[OrderService] DB table init warning: ${err.message}`);
  }
}
initDb();

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
    service: 'shopsphere-order-service',
    version: '9.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: {
      status: dbStatus,
      latencyMs: dbLatencyMs
    },
    queue: {
      configured: Boolean(SQS_QUEUE_URL),
      url: SQS_QUEUE_URL
    }
  });
});

// ------------------------------------------------------------------------------
// Order Management Endpoints
// ------------------------------------------------------------------------------

// List Orders
app.get(['/api/orders', '/orders'], async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 20');
    res.json({
      success: true,
      service: 'order-service',
      count: result.rows.length,
      data: result.rows
    });
  } catch (err) {
    res.status(500).json({ success: false, message: `Failed to fetch orders: ${err.message}` });
  }
});

// Order Status Polling
app.get(['/api/orders/:id/status', '/orders/:id/status'], async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) {
    return res.status(400).json({ success: false, message: 'Invalid order ID' });
  }

  try {
    const result = await pool.query('SELECT id, status, total_amount, sqs_message_id, created_at FROM orders WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Place Order (Stores in DB & Publishes to SQS)
app.post(['/api/orders', '/orders'], async (req, res) => {
  const { customerName, customerEmail, items, totalAmount } = req.body;

  if (!customerName || !customerEmail || !items || !totalAmount) {
    return res.status(400).json({
      success: false,
      message: 'Missing required order fields (customerName, customerEmail, items, totalAmount)'
    });
  }

  let orderId = null;
  let sqsMessageId = null;

  // Step 1: Insert order record in PostgreSQL
  try {
    const insertQuery = `
      INSERT INTO orders (customer_name, customer_email, total_amount, status, items)
      VALUES ($1, $2, $3, 'PENDING', $4)
      RETURNING id, created_at
    `;
    const dbRes = await pool.query(insertQuery, [customerName, customerEmail, totalAmount, JSON.stringify(items)]);
    orderId = dbRes.rows[0].id;
  } catch (dbErr) {
    return res.status(500).json({
      success: false,
      message: `Failed to create database order: ${dbErr.message}`
    });
  }

  // Step 2: Publish message to SQS Queue for Asynchronous Worker
  if (SQS_QUEUE_URL) {
    try {
      const payload = {
        orderId,
        customerName,
        customerEmail,
        totalAmount,
        items,
        timestamp: new Date().toISOString(),
        environment: 'stage9-microservices'
      };

      const sendCmd = new SendMessageCommand({
        QueueUrl: SQS_QUEUE_URL,
        MessageBody: JSON.stringify(payload),
        MessageAttributes: {
          OrderId: { DataType: 'String', StringValue: String(orderId) },
          Service: { DataType: 'String', StringValue: 'shopsphere-order-service' }
        }
      });

      const sqsRes = await sqsClient.send(sendCmd);
      sqsMessageId = sqsRes.MessageId;

      // Update order record with SQS Message ID
      await pool.query('UPDATE orders SET sqs_message_id = $1 WHERE id = $2', [sqsMessageId, orderId]);
    } catch (sqsErr) {
      console.warn(`[OrderService] SQS publish warning for order #${orderId}: ${sqsErr.message}`);
    }
  }

  res.status(201).json({
    success: true,
    message: 'Order created successfully and dispatched for async processing',
    orderId,
    status: 'PENDING',
    sqsMessageId: sqsMessageId || 'LOCAL_SIMULATED',
    service: 'shopsphere-order-service'
  });
});

app.listen(PORT, () => {
  console.log(`[OrderService] Microservice listening on port ${PORT}`);
});
