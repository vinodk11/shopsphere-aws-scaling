// ==============================================================================
// ShopSphere Microservice: Frontend Service (Stage 10 GitOps + Argo CD)
// Serves static web assets, visualizer and client proxies
// ==============================================================================
const express = require('express');
const path = require('path');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json({ limit: '100kb' }));
app.use(morgan('combined'));

// Serve Static Frontend Assets
app.use(express.static(path.join(__dirname, 'public'), {
  maxAge: '5m',
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, must-revalidate');
    }
  }
}));

// Health Check Endpoint (Required by EKS Probes and ALB Target Group)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    service: 'shopsphere-frontend-service',
    stage: 'Stage 10: GitOps & Argo CD',
    version: '10.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    architecture: {
      platform: 'Amazon EKS (Kubernetes)',
      gitops: 'Argo CD Automated Reconciliation',
      frontend: 'Frontend Web Container (Port 8080)',
      microservices: [
        { name: 'product-service', port: 8081, path: '/api/products*' },
        { name: 'order-service', port: 8082, path: '/api/orders*' },
        { name: 'user-sso-service', port: 8083, path: '/api/users*' }
      ]
    },
    servingInstance: {
      hostname: process.env.HOSTNAME || 'localhost',
      platform: process.platform,
      totalMemMB: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      freeMemMB: Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
    }
  });
});

// Fallback to index.html for SPA routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`[FrontendService] Stage 10 Frontend listening on port ${PORT}`);
});
