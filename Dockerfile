# Stage 1: Build Stage
FROM composer:2.2 AS composer

# Set working directory for the build
WORKDIR /app

# Copy the composer files
COPY composer.json composer.lock artisan bootstrap ./

# Install dependencies without development packages and optimize for production
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
#RUN composer install --no-progress --no-interaction

# Stage 2: Production Stage
FROM php:8.2-fpm-alpine AS app

# Set working directory
WORKDIR /var/www

# Install necessary system packages for PHP extensions
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxpm-dev \
    freetype-dev \
    oniguruma-dev \
    zip \
    unzip \
    bash

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Install and configure Opcache for performance
RUN docker-php-ext-install opcache \
    && { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Copy application source code to the container
COPY . /var/www

# Copy the installed vendor dependencies from the composer stage
#COPY --from=composer /app/vendor /var/www/vendor

# Set appropriate permissions for Laravel folders
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache \
    && touch /usr/local/var/log/php-fpm.log \
    && chown -R www-data /usr/local/var/log/php-fpm.log && chmod -R 775 /usr/local/var/log/php-fpm.log 
# Expose the PHP-FPM port
EXPOSE 9000

# Use a non-root user for better security
USER www-data

# Start PHP-FPM server
CMD ["php-fpm"]
