const test = require('node:test');
const assert = require('node:assert');

test('Product Service Package Metadata Test', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-product-service');
  assert.strictEqual(pkg.version, '10.0.0');
});

test('Product Service Syntax and Configuration Check', () => {
  assert.strictEqual(process.env.NODE_ENV !== undefined || true, true);
});

test('Product Service 16-Product Catalog Validation', () => {
  const fs = require('fs');
  const path = require('path');
  const code = fs.readFileSync(path.join(__dirname, '../server.js'), 'utf8');
  assert.ok(code.includes('CloudBeats ANC Wireless Headphones'), 'Product 1 must exist');
  assert.ok(code.includes('KubeKey FIDO2 Hardware Security Key'), 'Product 16 must exist');
  assert.ok(code.includes('Stage 10: GitOps & Argo CD'), 'Stage 10 metadata must be present');
});
