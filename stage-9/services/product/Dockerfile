# ==============================================================================
# Multi-Stage Hardened Dockerfile: Product Microservice (Stage 9 EKS)
# ==============================================================================

# Stage 1: Build Dependencies
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Production Hardened Runtime
FROM node:18-alpine AS runner

# Security: Install dumb-init for proper PID 1 signal handling
RUN apk add --no-cache dumb-init curl

WORKDIR /usr/src/app

# Security: Create non-root system group and user (UID 10001)
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

# Copy node_modules from builder
COPY --from=builder --chown=appuser:appgroup /usr/src/app/node_modules ./node_modules
COPY --chown=appuser:appgroup package*.json ./
COPY --chown=appuser:appgroup server.js ./

# Switch to unprivileged user
USER 10001

ENV NODE_ENV=production \
    PORT=8081

EXPOSE 8081

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8081/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
