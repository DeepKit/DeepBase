# UniBase Web API Service Docker Image
# Base image for running Delphi/FPC compiled applications

FROM ubuntu:22.04

LABEL maintainer="UniBase Framework Team"
LABEL description="UniBase Web API Service Container"
LABEL version="1.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install required dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libcurl4 \
    zlib1g \
    tzdata \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create application user and directories
RUN groupadd -r unibase && useradd -r -g unibase unibase \
    && mkdir -p /app /app/config /app/logs /app/data \
    && chown -R unibase:unibase /app

# Set working directory
WORKDIR /app

# Copy application files
COPY --chown=unibase:unibase bin/WebApiService /app/
COPY --chown=unibase:unibase config/ /app/config/

# Make the binary executable
RUN chmod +x /app/WebApiService

# Expose ports
# HTTP
EXPOSE 8080
# HTTPS
EXPOSE 8443
# WebSocket
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Switch to non-root user
USER unibase

# Set default command
CMD ["/app/WebApiService"]

# Environment variables that can be overridden
ENV API_HOST=0.0.0.0
ENV API_PORT=8080
ENV API_SSL_ENABLED=false
ENV API_LOG_LEVEL=info
ENV API_MAX_CONNECTIONS=1000
ENV API_CORS_ORIGINS=*
