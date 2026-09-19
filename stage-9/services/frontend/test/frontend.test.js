const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

test('Frontend Service Package Metadata Test', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-frontend-service');
  assert.strictEqual(pkg.version, '9.0.0');
});

test('Frontend Service Static Assets Integrity Test', () => {
  const htmlPath = path.join(__dirname, '../public/index.html');
  assert.ok(fs.existsSync(htmlPath), 'index.html must exist');
  const htmlContent = fs.readFileSync(htmlPath, 'utf8');
  assert.ok(htmlContent.includes('Stage 9: Amazon EKS & Microservices'), 'Must contain Stage 9 badge');
  assert.ok(htmlContent.includes('Single Sign-On'), 'Must contain SSO integration');

  const cssPath = path.join(__dirname, '../public/styles.css');
  assert.ok(fs.existsSync(cssPath), 'styles.css must exist');
});
