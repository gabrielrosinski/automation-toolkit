# Multi-stage PHP Application Dockerfile - Debian optimized
# Build stage compiles extensions, runtime stage is lean

# ============================================================================
# Stage 1: Builder - compile PHP extensions
# ============================================================================
FROM php:{{PHP_VERSION}}-apache AS builder

# Install build dependencies (needed for compiling extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 2: Runtime - lean production image
# ============================================================================
FROM php:{{PHP_VERSION}}-apache

LABEL maintainer="DevOps Team"
LABEL version="1.0"
LABEL description="PHP application container (multi-stage, optimized)"

# Install ONLY runtime dependencies (not -dev packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpng16-16 \
    libonig5 \
    libxml2 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info

# Copy compiled PHP extensions from builder stage
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Disable unnecessary Apache modules to reduce attack surface and size
# Use || true to prevent build failure if module doesn't exist
RUN a2dismod -f access_compat || true \
    && a2dismod -f auth_basic || true \
    && a2dismod -f authn_file || true \
    && a2dismod -f authz_host || true \
    && a2dismod -f authz_user || true \
    && a2dismod -f autoindex || true \
    && a2dismod -f deflate || true \
    && a2dismod -f filter || true \
    && a2dismod -f negotiation || true \
    && a2dismod -f status || true

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Configure Apache to run on non-privileged port and as non-root
RUN sed -i 's/Listen 80/Listen {{APP_PORT}}/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:{{APP_PORT}}/' /etc/apache2/sites-available/000-default.conf \
    && chown -R www-data:www-data /var/log/apache2 /var/run/apache2 /var/www/html

# Copy application code (as late as possible for better layer caching)
# --chown combines copy + ownership change in one layer
COPY --chown=www-data:www-data *.php /var/www/html/

# Set permissions
RUN chmod -R 755 /var/www/html

# Expose port (non-privileged)
EXPOSE {{APP_PORT}}

# Switch to non-root user
USER www-data

# Health check - silent but show errors on failure
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -sSf http://localhost:{{APP_PORT}}/ || exit 1

# Start Apache as non-root
CMD ["apache2-foreground"]
