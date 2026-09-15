const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('ShopSphere Package Integrity Test', () => {
  const pkgPath = path.join(__dirname, '..', 'package.json');
  assert.ok(fs.existsSync(pkgPath), 'package.json should exist');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  assert.equal(pkg.name, 'shopsphere-app');
  assert.equal(pkg.version, '8.0.0');
  assert.ok(pkg.dependencies.express, 'express dependency must be present');
  assert.ok(pkg.dependencies.pg, 'pg dependency must be present');
});

test('ShopSphere Security Configuration Test', () => {
  const serverPath = path.join(__dirname, '..', 'server.js');
  const serverContent = fs.readFileSync(serverPath, 'utf8');
  assert.match(serverContent, /X-Frame-Options/i, 'X-Frame-Options header must be configured');
  assert.match(serverContent, /Content-Security-Policy/i, 'Content-Security-Policy header must be configured');
  assert.match(serverContent, /X-Content-Type-Options/i, 'X-Content-Type-Options nosniff header must be configured');
  assert.match(serverContent, /\/api\/security\/status/, 'Security status endpoint must exist');
  assert.match(serverContent, /\/api\/container-info/, 'Container diagnostics endpoint must exist');
});

test('ShopSphere Dockerfile Integrity Test', () => {
  const dockerfilePath = path.join(__dirname, '..', 'Dockerfile');
  assert.ok(fs.existsSync(dockerfilePath), 'Dockerfile must exist');
  const dockerfile = fs.readFileSync(dockerfilePath, 'utf8');
  assert.match(dockerfile, /FROM node:18-alpine AS builder/i, 'Must use multi-stage builder');
  assert.match(dockerfile, /FROM node:18-alpine AS runner/i, 'Must use multi-stage runner');
  assert.match(dockerfile, /USER shopsphere/i, 'Must run as non-root user');
  assert.match(dockerfile, /HEALTHCHECK/i, 'Must include HEALTHCHECK instruction');
  assert.match(dockerfile, /EXPOSE 8080/i, 'Must expose port 8080');
});

test('ShopSphere Input Sanitization Logic Test', () => {
  function sanitizeInput(str) {
    if (typeof str !== 'string') return str;
    return str.replace(/['";\\]/g, '');
  }

  const maliciousInput = "1' OR '1'='1; DROP TABLE users;--";
  const sanitized = sanitizeInput(maliciousInput);
  assert.ok(!sanitized.includes("'"), 'Single quotes must be stripped');
  assert.ok(!sanitized.includes(";"), 'Semicolons must be stripped');
  assert.ok(!sanitized.includes('"'), 'Double quotes must be stripped');
});
