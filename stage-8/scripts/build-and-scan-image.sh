#!/usr/bin/env bash
# ==============================================================================
# ShopSphere Stage 8 - Docker Build & Image Security Scan Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/../app"
SECURITY_DIR="${SCRIPT_DIR}/../security"
IMAGE_TAG="${1:-shopsphere-app:8.0.0}"

echo "=================================================================="
echo "🐳 Building Multi-Stage Hardened Docker Image: ${IMAGE_TAG}"
echo "=================================================================="

cd "${APP_DIR}"
docker build -t "${IMAGE_TAG}" -f Dockerfile .

echo "=================================================================="
echo "🛡️ Scanning Container Image with Trivy (Vulnerabilities only)"
echo "=================================================================="

docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${SECURITY_DIR}:/security" \
    aquasec/trivy:latest image \
    --scanners vuln \
    --severity HIGH,CRITICAL \
    --config /security/container/trivy-image.yaml \
    "${IMAGE_TAG}"

echo "✅ Docker Image build & scan completed successfully: ${IMAGE_TAG}"
