/**
 * ShopSphere Stage 5 — Serverless Order Processing Lambda Worker
 * 
 * Consumes order-processing events asynchronously from Amazon SQS, executes
 * decoupled fulfillment workflows (validation, payment settlement, fraud scoring,
 * warehouse dispatch), logs structured audit trails to AWS CloudWatch Logs, and
 * optionally synchronizes order status with Amazon RDS PostgreSQL.
 */

'use strict';

const crypto = require('crypto');

// Optional PostgreSQL driver (if bundled or layered)
let pg = null;
try {
  pg = require('pg');
} catch {
  // Gracefully falls back to pure serverless background worker mode
}

const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';
const STAGE = process.env.STAGE || 'stage-5';
const LOG_LEVEL = (process.env.LOG_LEVEL || 'info').toLowerCase();
const SIMULATE_PROCESSING_TIME_MS = parseInt(process.env.SIMULATE_PROCESSING_TIME_MS || '80', 10);

// Optional DB Configuration
const DB_HOST = process.env.DB_HOST || '';
const DB_PORT = parseInt(process.env.DB_PORT || '5432', 10);
const DB_NAME = process.env.DB_NAME || 'shopspheredb';
const DB_USER = process.env.DB_USER || 'shopsphere_user';
const DB_PASSWORD = process.env.DB_PASSWORD || '';

let dbPool = null;
function getDbPool() {
  if (!dbPool && pg && DB_HOST && DB_PASSWORD) {
    dbPool = new pg.Pool({
      host: DB_HOST,
      port: DB_PORT,
      database: DB_NAME,
      user: DB_USER,
      password: DB_PASSWORD,
      max: 2,
      connectionTimeoutMillis: 3000,
      ssl: DB_HOST.includes('rds.amazonaws.com') ? { rejectUnauthorized: false } : false
    });
  }
  return dbPool;
}

/**
 * Structured logger writing JSON lines to AWS CloudWatch Logs
 */
function log(level, message, metadata = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level: level.toUpperCase(),
    service: 'shopsphere-order-processor',
    stage: STAGE,
    environment: ENVIRONMENT,
    message,
    ...metadata
  };
  if (level === 'error') {
    console.error(JSON.stringify(entry));
  } else if (level === 'warn') {
    console.warn(JSON.stringify(entry));
  } else {
    console.log(JSON.stringify(entry));
  }
}

/**
 * Simulates asynchronous downstream latency
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Main Lambda Handler for SQS Event Source Mapping
 *
 * @param {Object} event SQS Event containing Records
 * @param {Object} context Lambda Execution Context
 * @returns {Promise<Object>} Batch item failure response
 */
exports.handler = async (event, context) => {
  const startTime = Date.now();
  const awsRequestId = context ? context.awsRequestId : crypto.randomUUID();
  const batchItemFailures = [];

  const records = event.Records || [];
  log('info', `Received SQS batch with ${records.length} record(s)`, {
    awsRequestId,
    batchSize: records.length,
    remainingTimeMs: context ? context.getRemainingTimeInMillis() : null
  });

  for (const record of records) {
    const recordStartTime = Date.now();
    const messageId = record.messageId;

    try {
      // 1. Parse SQS Message Payload
      let payload;
      try {
        payload = JSON.parse(record.body);
      } catch (parseErr) {
        log('error', `Failed to parse SQS message JSON body: ${parseErr.message}`, {
          messageId,
          rawBody: record.body
        });
        // Unparseable message will fail and route to DLQ
        throw new Error(`JSON_PARSE_ERROR: Invalid message body in SQS message ${messageId}`);
      }

      const {
        eventType = 'ORDER_CREATED',
        orderId,
        customerId,
        customerName,
        customerEmail,
        shippingAddress,
        totalAmount,
        items,
        timestamp = new Date().toISOString(),
        simulateFailure = false
      } = payload;

      log('info', `Processing order event: ${eventType} (Order #${orderId || 'N/A'})`, {
        messageId,
        awsRequestId,
        eventType,
        orderId,
        customerId,
        customerEmail,
        totalAmount,
        itemCount: Array.isArray(items) ? items.length : 0,
        eventTimestamp: timestamp
      });

      // 2. Simulated Failure Hook for DLQ and Redrive Testing
      if (simulateFailure === true || payload.failOrder === true) {
        log('warn', `Simulated processing failure requested for Order #${orderId} (DLQ test)`, {
          messageId,
          orderId
        });
        throw new Error(`SIMULATED_WORKER_FAILURE: Intentional error to trigger SQS DLQ redrive for Order #${orderId}`);
      }

      // 3. Validation
      if (!orderId && orderId !== 0) {
        log('warn', `Missing orderId in message payload: ${messageId}`);
      }

      // 4. Asynchronous Background Fulfillment Stages
      // Step A: Fraud Detection & Risk Scoring
      await sleep(Math.floor(SIMULATE_PROCESSING_TIME_MS * 0.3));
      const riskScore = Math.floor(Math.random() * 15); // Low risk < 20
      const fraudCheckPassed = riskScore < 20;

      // Step B: Payment Gateway Settlement
      await sleep(Math.floor(SIMULATE_PROCESSING_TIME_MS * 0.4));
      const paymentRef = `PAY-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

      // Step C: Warehouse Inventory Allocation & Dispatch Notice
      await sleep(Math.floor(SIMULATE_PROCESSING_TIME_MS * 0.3));
      const fulfillmentRef = `FULFILL-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

      // 5. Update Database Status if Database is Configured
      let dbUpdated = false;
      const pool = getDbPool();
      if (pool && orderId) {
        try {
          const updateQuery = `
            UPDATE orders 
            SET status = 'FULFILLED',
                processed_by_worker = $1,
                processed_at = NOW()
            WHERE id = $2;
          `;
          const workerId = `lambda:${context ? context.functionName : 'order-processor'}:${awsRequestId.slice(0, 8)}`;
          await pool.query(updateQuery, [workerId, orderId]);
          dbUpdated = true;
          log('info', `Successfully updated Amazon RDS order #${orderId} to FULFILLED`, {
            orderId,
            workerId
          });
        } catch (dbErr) {
          log('warn', `Notice: Unable to update RDS directly (${dbErr.message}). Continuing with processed event.`, {
            orderId,
            error: dbErr.message
          });
        }
      }

      const processingDurationMs = Date.now() - recordStartTime;

      // 6. CloudWatch Audit Logging
      log('info', `Order #${orderId || messageId} processed and fulfilled successfully`, {
        messageId,
        awsRequestId,
        orderId,
        eventType,
        status: 'FULFILLED',
        paymentReference: paymentRef,
        fulfillmentReference: fulfillmentRef,
        fraudRiskScore: riskScore,
        fraudCheckPassed,
        dbSynchronized: dbUpdated,
        processingDurationMs,
        approximateReceiveCount: record.attributes ? record.attributes.ApproximateReceiveCount : '1'
      });

    } catch (recordError) {
      log('error', `Error processing SQS record ${messageId}: ${recordError.message}`, {
        messageId,
        awsRequestId,
        error: recordError.message,
        stack: recordError.stack
      });

      // Track failed message for partial batch response
      batchItemFailures.push({ itemIdentifier: messageId });
    }
  }

  const totalDurationMs = Date.now() - startTime;
  log('info', `Batch processing complete. Processed ${records.length - batchItemFailures.length}/${records.length} message(s) successfully.`, {
    awsRequestId,
    totalRecords: records.length,
    failedRecords: batchItemFailures.length,
    totalDurationMs
  });

  return { batchItemFailures };
};
