// ==============================================================================
// ShopSphere Microservice: Frontend UI Service (Stage 9 EKS)
// Serves Modern Web Interface, Architecture Visualizer, and SSO Client
// ==============================================================================
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const os = require('os');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(morgan('combined'));

// Serve static assets from public directory
app.use(express.static(path.join(__dirname, 'public')));

// ------------------------------------------------------------------------------
// Health Check Endpoint (Required by EKS Probes and ALB Target Group)
// ------------------------------------------------------------------------------
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    service: 'shopsphere-frontend-service',
    stage: 'Stage 9: Amazon EKS & Microservices',
    version: '9.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    architecture: {
      platform: 'Amazon EKS (Kubernetes)',
      frontend: 'Frontend Web Container (Port 8080)',
      microservices: [
        { name: 'product-service', port: 8081, path: '/api/products*' },
        { name: 'order-service', port: 8082, path: '/api/orders*' },
        { name: 'user-sso-service', port: 8083, path: '/api/users*' }
      ]
    },
    servingInstance: {
      hostname: os.hostname(),
      platform: os.platform(),
      totalMemMB: Math.round(os.totalmem() / 1024 / 1024),
      freeMemMB: Math.round(os.freemem() / 1024 / 1024)
    }
  });
});

// Fallback to index.html for single page navigation
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`[FrontendService] Stage 9 Web UI container running on port ${PORT}`);
});
