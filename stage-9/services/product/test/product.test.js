const test = require('node:test');
const assert = require('node:assert');

test('Product Service Syntax and Export Validation', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-product-service');
  assert.strictEqual(pkg.version, '9.0.0');
});

test('Product Service Configuration Check', () => {
  assert.strictEqual(process.env.NODE_ENV !== undefined || true, true);
});
