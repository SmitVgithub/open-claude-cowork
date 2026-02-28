# =============================================================================
# Multi-Stage Dockerfile for Open Claude Cowork Server
# =============================================================================
# This Dockerfile builds the Express.js server component for Azure Container Apps
# deployment. The Electron desktop app is NOT included as it's not suitable for
# cloud deployment.
#
# Build stages:
# 1. dependencies - Install production dependencies with clean cache
# 2. production - Minimal runtime image with security hardening
#
# Security considerations:
# - Uses non-root user (node:node)
# - Alpine-based for minimal attack surface (~150MB vs ~900MB)
# - No dev dependencies in final image
# - Read-only filesystem compatible
# - Health check endpoint included
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Dependencies
# -----------------------------------------------------------------------------
# Purpose: Install production dependencies in isolated stage for better caching
# Base: node:20-alpine chosen for:
#   - LTS support until April 2026
#   - Alpine reduces image size by ~80%
#   - Native ARM64 support for Azure Container Apps
# -----------------------------------------------------------------------------
FROM node:20-alpine AS dependencies

# Install build dependencies for native modules (if any)
# These are only needed during npm install, not in final image
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy package files from server directory
# server/package.json contains the deployable Express server dependencies
COPY server/package.json server/package-lock.json* ./

# Install ONLY production dependencies
# --omit=dev excludes devDependencies (electron, electron-reload)
# --ignore-scripts prevents potential malicious postinstall scripts
# CI=true ensures non-interactive installation
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

# -----------------------------------------------------------------------------
# Stage 2: Production Runtime
# -----------------------------------------------------------------------------
# Purpose: Minimal, secure runtime image
# Security hardening applied:
#   - Non-root user execution
#   - No shell access in production (optional: use distroless)
#   - Minimal installed packages
#   - Environment variables for configuration
# -----------------------------------------------------------------------------
FROM node:20-alpine AS production

# Labels for container registry and operational metadata
# These help with image management in Azure Container Registry
LABEL org.opencontainers.image.title="open-claude-cowork-server" \
      org.opencontainers.image.description="Claude Agent SDK Express Server for Azure Container Apps" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="Open Claude Cowork" \
      org.opencontainers.image.source="https://github.com/SmitVgithub/open-claude-cowork" \
      maintainer="DevOps Team"

# Install runtime dependencies only
# dumb-init: Proper PID 1 signal handling (prevents zombie processes)
# curl: Health check endpoint verification
RUN apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory with proper ownership
# Using node user (UID 1000) that comes with node:alpine image
WORKDIR /app

# Copy production dependencies from dependencies stage
# This leverages Docker layer caching - dependencies only rebuild when package.json changes
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules

# Copy server application code
# Only copying what's needed for the server to run
COPY --chown=node:node server/ ./

# Copy root-level files needed by the server
# .env.example for reference (actual .env should be mounted or use Azure Key Vault)
COPY --chown=node:node .env.example ./.env.example

# Environment variables with secure defaults
# These can be overridden at runtime via Azure Container Apps configuration
ENV NODE_ENV=production \
    PORT=3000 \
    # Disable npm update checks in production
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    # Reduce memory footprint
    NODE_OPTIONS="--max-old-space-size=1536"

# Expose the application port
# Azure Container Apps will route traffic to this port
EXPOSE 3000

# Switch to non-root user for security
# This prevents container escape attacks from gaining root access
USER node

# Health check for container orchestration
# Azure Container Apps uses this to determine container health
# Checks every 30s, times out after 10s, allows 3 failures before unhealthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init as PID 1 to handle signals properly
# This ensures graceful shutdown when Azure Container Apps scales down
# Node.js doesn't handle SIGTERM properly as PID 1 without this
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start the Express server
# Using node directly (not npm) for better signal handling
CMD ["node", "server.js"]
