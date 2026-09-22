const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

test('Frontend Service Package Metadata Test', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-frontend-service');
  assert.strictEqual(pkg.version, '10.0.0');
});

test('Frontend Service Static Assets Integrity Test', () => {
  const htmlPath = path.join(__dirname, '../public/index.html');
  assert.ok(fs.existsSync(htmlPath), 'index.html must exist');
  const htmlContent = fs.readFileSync(htmlPath, 'utf8');
  assert.ok(htmlContent.includes('Stage 10: GitOps & Argo CD'), 'Must contain Stage 10 badge');
  assert.ok(htmlContent.includes('landingAuthSection'), 'Must contain landing auth gateway');
  assert.ok(htmlContent.includes('Sign In to View Products'), 'Must contain Sign In to Products flow');
  assert.ok(htmlContent.includes('Create Account') && htmlContent.includes('Unlock Products'), 'Must contain Sign Up flow');
  assert.ok(htmlContent.includes('authenticatedCatalogSection'), 'Must contain authenticated catalog section');

  const cssPath = path.join(__dirname, '../public/styles.css');
  assert.ok(fs.existsSync(cssPath), 'styles.css must exist');
});

test('Frontend Service Server Route and Metadata Test', () => {
  const serverPath = path.join(__dirname, '../server.js');
  assert.ok(fs.existsSync(serverPath), 'server.js must exist');
  const serverContent = fs.readFileSync(serverPath, 'utf8');
  assert.ok(serverContent.includes('/health'), 'Must have health check');
  assert.ok(serverContent.includes('Stage 10: GitOps & Argo CD'), 'Must have Stage 10 health payload');
});
