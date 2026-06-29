#!/bin/sh
set -e

# Ensure storage directories exist
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/testing
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/tmp
mkdir -p /var/www/html/bootstrap/cache

# Fix ownership: Docker mounts ./app as root, but PHP-FPM runs as www-data
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# Execute the main command as www-data
exec su-exec www-data "$@"
