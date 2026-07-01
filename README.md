# Laravel CRM — Docker Deployment

Dockerized deployment for [VentureDrake Laravel CRM](https://github.com/venturedrake/laravel-crm) (v2.3), an open-source CRM built on Laravel 13 + Livewire + Tailwind CSS.

## Features

- **Contacts** — People and organizations
- **Leads** — Track prospects through a pipeline
- **Deals** — Kanban board for active opportunities
- **Quotes, Orders, Invoices** — Full sales lifecycle
- **Deliveries & Purchase Orders** — Fulfillment tracking
- **Teams** — Group users with role-based permissions
- **Chat** — Internal team messaging
- **Email & SMS Marketing** — Campaign management
- **Monitoring** — Uptime and SSL monitoring
- **Features Board** — Public feature requests with voting

## Quick Start

```bash
git clone -b feature/webhooks https://github.com/Shudiak/laravel-crm.git
cd laravel-crm
chmod +x deploy.sh
./deploy.sh
```

The script handles everything:
1. Environment setup with secure random passwords
2. Docker image build (PHP 8.3-FPM with all required extensions)
3. Composer dependency installation
4. Laravel Breeze authentication setup
5. CRM package installation and configuration
6. Database migrations and seeds
7. Admin user creation with Owner role
8. Storage permission fix
9. Container startup with health check

After deployment, the script prints the login URL and admin credentials.

## Architecture

```
laravel-crm/
├── deploy.sh              # Full automated deployment script
├── .env.example           # Environment template
├── .gitignore
├── docker-compose.yml     # 3-service stack: app + web + db
├── Dockerfile             # PHP 8.3-FPM Alpine + extensions + Composer
├── nginx/
│   └── default.conf       # Nginx reverse proxy for PHP-FPM
├── php/
│   └── local.ini          # PHP overrides (uploads, memory, timeout)
└── app/                   # Laravel project (generated on deploy)
```

## Services

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| `crm-app` | Custom PHP 8.3-FPM | — | Application with Composer + CRM |
| `crm-web` | Nginx Alpine | `8080:80` | Web server / reverse proxy |
| `crm-db` | MariaDB 10.11 | — | Database (Docker volume) |

## Requirements

- **Docker** 20.10+ and **Docker Compose** v2+
- **2 GB RAM** minimum (4 GB recommended)
- **5 GB** disk space
- Ports: `8080` (or modify `docker-compose.yml`)

## Configuration

### Custom Domain / URL

Edit `.env` after deployment:
```env
APP_URL=https://crm.yourdomain.com
```

### Custom Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "3000:80"   # Change 8080 to your preferred port
```

### Mail Configuration

Edit `.env` to configure SMTP:
```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.yourdomain.com
MAIL_PORT=587
MAIL_USERNAME=your@email.com
MAIL_PASSWORD=your-password
MAIL_ENCRYPTION=tls
```

### CRM Settings

All CRM settings are in `.env`:
```env
LARAVEL_CRM_OWNER=admin@example.com    # Primary owner email
LARAVEL_CRM_CURRENCY=COP               # Currency code
LARAVEL_CRM_COUNTRY=Colombia            # Country
LARAVEL_CRM_TIMEZONE=America/Bogota    # Timezone
LARAVEL_CRM_LANGUAGE=english           # Language
```

### Enable/Disable Modules

Edit `app/config/laravel-crm.php` (generated on deploy):
```php
'modules' => [
    'leads',
    'deals',
    'quotes',
    'orders',
    'invoices',
    // 'deliveries',      // Remove to disable
    // 'purchase-orders', // Remove to disable
    // 'chat',
    // 'email-marketing',
    // 'sms-marketing',
    // 'features',
    // 'monitoring',
],
```

## Common Commands

```bash
# Start all containers
docker compose up -d

# View logs
docker compose logs -f

# Restart after config change
docker compose restart app web

# Stop everything
docker compose down

# Stop + delete database volume (destructive!)
docker compose down -v

# Run artisan commands
docker compose exec app php artisan <command>

# Run Composer
docker compose exec app composer <command>

# Fix storage permissions
docker compose exec app chown -R www-data:www-data /var/www/html/storage
```

## Known Fixes Applied

This deployment includes fixes for common issues encountered during initial setup:

- **Storage permissions**: PHP-FPM runs as `www-data`; the Dockerfile switches to this user to prevent 403/500 errors
- **tempnam() warning**: PHP 8.x emits an E_WARNING on `tempnam()` that Laravel converts to an ErrorException; suppressed with `@`
- **CRM owner**: `LARAVEL_CRM_OWNER` must match the admin user email in `.env`, otherwise the dashboard returns 403
- **Route prefix**: CRM lives at `/crm/` (not root); login is at `/crm/login`, dashboard at `/crm/dashboard`

## Troubleshooting

### 500 Internal Server Error on /crm/login

```bash
docker compose exec app chown -R www-data:www-data /var/www/html/storage
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear
```

### 403 Forbidden on /crm/dashboard

Ensure `LARAVEL_CRM_OWNER` in `.env` matches your admin user email:
```bash
grep LARAVEL_CRM_OWNER .env
```

### Database connection failed

```bash
docker compose restart db
docker compose exec db mysqladmin ping -h localhost
```

### Blank page / no CSS

Assets may need rebuilding:
```bash
docker compose exec app npm install
docker compose exec app npm run build
```

## License

- **Laravel CRM**: [MIT License](https://github.com/venturedrake/laravel-crm/blob/master/LICENSE) by [Andrew Drake](https://github.com/andrewdrake)
- **Laravel Framework**: [MIT License](https://laravel.com/docs)
- **Docker Deployment Bootstrap**: MIT License
