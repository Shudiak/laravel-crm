FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
    curl \
    git \
    zip \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    oniguruma-dev \
    icu-dev \
    libxml2-dev \
    nodejs \
    npm

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    mbstring \
    xml \
    bcmath \
    zip \
    gd \
    intl \
    exif \
    pcntl \
    opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Fix PHP-FPM runs as www-data but files are owned by root
RUN chown -R www-data:www-data /var/www/html
USER www-data
