# PHP Application Dockerfile
# Optimized for production with best practices

FROM php:{{PHP_VERSION}}-apache AS base

LABEL maintainer="DevOps Team"
LABEL version="1.0"
LABEL description="PHP application container"

# Install system dependencies - use --no-install-recommends to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

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
