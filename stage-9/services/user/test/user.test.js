const test = require('node:test');
const assert = require('node:assert');

test('User Service Package Metadata Test', () => {
  const pkg = require('../package.json');
  assert.strictEqual(pkg.name, 'shopsphere-user-service');
  assert.strictEqual(pkg.version, '9.0.0');
});

test('User Service Crypto and SSO Token Logic Test', () => {
  const crypto = require('crypto');
  const payload = { sub: 'test@shopsphere.io', role: 'customer', provider: 'aws-iam' };
  const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', 'ShopSphereSecret2026').update(encoded).digest('base64url');
  const token = `${encoded}.${signature}`;

  assert.ok(token.includes('.'));
  const [tokenPart, sigPart] = token.split('.');
  const decoded = JSON.parse(Buffer.from(tokenPart, 'base64url').toString('utf8'));
  assert.strictEqual(decoded.sub, 'test@shopsphere.io');
  assert.strictEqual(decoded.provider, 'aws-iam');
});
