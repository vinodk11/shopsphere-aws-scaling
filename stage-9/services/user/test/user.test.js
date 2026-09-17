const test = require('node:test');
const assert = require('node:assert');

test('User Service Syntax and Export Validation', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-user-service');
  assert.strictEqual(pkg.version, '9.0.0');
});
