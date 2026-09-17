# ==============================================================================
# Multi-Stage Hardened Dockerfile: Order Microservice (Stage 9 EKS)
# ==============================================================================

# Stage 1: Build Dependencies
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Production Hardened Runtime
FROM node:18-alpine AS runner

RUN apk add --no-cache dumb-init curl

WORKDIR /usr/src/app

RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

COPY --from=builder --chown=appuser:appgroup /usr/src/app/node_modules ./node_modules
COPY --chown=appuser:appgroup package*.json ./
COPY --chown=appuser:appgroup server.js ./

USER 10001

ENV NODE_ENV=production \
    PORT=8082

EXPOSE 8082

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8082/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
