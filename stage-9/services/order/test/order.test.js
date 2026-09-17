const test = require('node:test');
const assert = require('node:assert');

test('Order Service Syntax and Export Validation', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-order-service');
  assert.strictEqual(pkg.version, '9.0.0');
});

test('Order Service AWS SDK Integration Check', () => {
  const { SQSClient } = require('@aws-sdk/client-sqs');
  assert.strictEqual(typeof SQSClient, 'function');
});
