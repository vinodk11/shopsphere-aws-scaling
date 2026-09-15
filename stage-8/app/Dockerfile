# ==============================================================================
# ShopSphere Stage 8 - Multi-Stage, Hardened Production Dockerfile
# ==============================================================================
# Best Practices Implemented:
#   1. Multi-Stage Build: Separates dependency build tooling from runtime image
#   2. Minimal Attack Surface: Built on lightweight, patched Alpine Linux
#   3. Non-Root Execution: Runs as dedicated 'shopsphere' (UID 10001) user
#   4. Immutable Production Artifact: Excludes dev dependencies, tests & build tools
#   5. Native Healthcheck: Container self-healing & orchestrator liveness checks
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build & Dependencies
# ------------------------------------------------------------------------------
FROM node:18-alpine AS builder

WORKDIR /app

# Install security patches
RUN apk update && apk upgrade --no-cache

# Copy package manifests first for optimal Docker layer caching
COPY package.json ./

# Install production dependencies only
RUN npm install --omit=dev --cache /tmp/.npm && rm -rf /tmp/.npm

# Copy application source code
COPY server.js ./
COPY db/ ./db/
COPY public/ ./public/

# ------------------------------------------------------------------------------
# Stage 2: Hardened Runtime Container
# ------------------------------------------------------------------------------
FROM node:18-alpine AS runner

LABEL maintainer="ShopSphere Engineering <devops@shopsphere.internal>"
LABEL version="8.0.0"
LABEL description="ShopSphere Containerized E-Commerce Application"

# Update OS packages to mitigate base image CVEs
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache wget curl dumb-init && \
    rm -rf /var/cache/apk/*

# Create unprivileged system group and user (Non-root security hardening)
RUN addgroup -g 10001 -S shopsphere && \
    adduser -u 10001 -S shopsphere -G shopsphere -h /app -s /bin/sh

WORKDIR /app

# Set production environment variables
ENV NODE_ENV=production \
    PORT=8080 \
    STAGE_NAME=stage-8

# Copy runtime assets from builder with ownership
COPY --from=builder --chown=shopsphere:shopsphere /app/node_modules ./node_modules
COPY --from=builder --chown=shopsphere:shopsphere /app/package.json ./package.json
COPY --from=builder --chown=shopsphere:shopsphere /app/server.js ./server.js
COPY --from=builder --chown=shopsphere:shopsphere /app/db ./db
COPY --from=builder --chown=shopsphere:shopsphere /app/public ./public

# Switch to non-root user
USER shopsphere

# Expose application port
EXPOSE 8080

# Native Container Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1

# Use dumb-init for proper POSIX PID 1 signal forwarding and zombie reaper
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Launch application
CMD ["node", "server.js"]
