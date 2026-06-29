#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
# Laravel CRM — Docker Deployment Bootstrap
# ═══════════════════════════════════════════════════════════
# Usage: chmod +x deploy.sh && ./deploy.sh
#
# This script automates the full deployment:
#   1. Copies .env.example → .env if needed
#   2. Generates secure random passwords
#   3. Builds the PHP-FPM Docker image
#   4. Starts database and waits for it
#   5. Installs Composer dependencies (as root in container)
#   6. Generates APP_KEY
#   7. Installs Laravel Breeze
#   8. Runs CRM installer + migrations + seeds
#   9. Creates admin user with Owner role
#  10. Fixes storage permissions
#  11. Starts all containers and shows login credentials
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Prerequisites ───────────────────────────────────────
command -v docker >/dev/null 2>&1 || error "Docker is required. Install it first."

COMPOSE_CMD="docker compose"
if ! docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
fi

# Helper: run a command inside the app container as root
docker_exec_root() {
    $COMPOSE_CMD exec -T -u root app "$@"
}

# Helper: run a command inside the app container as www-data
docker_exec() {
    $COMPOSE_CMD exec -T app "$@"
}

# ─── Step 1: Environment file ───────────────────────────
info "Setting up environment..."

if [ ! -f .env ]; then
    cp .env.example .env
    info "Created .env from .env.example"
else
    warn ".env already exists — skipping creation"
fi

# ─── Step 2: Generate secure passwords ──────────────────
if grep -q "CHANGE\.\.\." .env 2>/dev/null; then
    DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo example.com)
    CRM_OWNER_EMAIL="admin@${HOSTNAME_FQDN}"

    # Update .env
    sed -i "s|CHANGE.*DB_PASSWORD_HERE|${DB_PASS}|g" .env
    sed -i "s|CHANGE.*ROOT_PASSWORD_HERE|${ROOT_PASS}|g" .env
    sed -i "s|admin@example.com|${CRM_OWNER_EMAIL}|g" .env

    # Update docker-compose.yml
    sed -i "s|crm_pass_2026|${DB_PASS}|g" docker-compose.yml
    sed -i "s|crm_root_2026|${ROOT_PASS}|g" docker-compose.yml

    info "Generated secure DB credentials"
else
    warn "Credentials already set in .env — skipping"
fi

# ─── Step 3: Build Docker image ─────────────────────────
info "Building PHP-FPM Docker image (this may take a few minutes)..."
$COMPOSE_CMD build app

# ─── Step 4: Start database first ───────────────────────
info "Starting database..."
$COMPOSE_CMD up -d db
sleep 5

info "Waiting for database to be ready..."
RETRIES=30
until $COMPOSE_CMD exec -T db mysqladmin ping -h localhost -u root --silent 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -le 0 ]; then
        error "Database failed to start after 30 retries"
    fi
    sleep 2
done
info "Database is ready"

# ─── Step 5: Start app container (needed for exec) ──────
info "Starting app container..."
$COMPOSE_CMD up -d app
sleep 3

# ─── Step 6: Install Composer dependencies ──────────────
info "Installing Composer dependencies (Laravel + CRM package)..."
# Run as root because the volume is owned by root on the host
docker_exec_root composer install --no-interaction --optimize-autoloader

# ─── Step 7: Fix permissions after composer install ─────
info "Fixing storage permissions..."
docker_exec_root mkdir -p /var/www/html/storage/framework/views \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/testing \
    /var/www/html/storage/logs \
    /var/www/html/storage/tmp \
    /var/www/html/bootstrap/cache
docker_exec_root chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# ─── Step 8: Generate APP_KEY ───────────────────────────
info "Generating application key..."
docker_exec php artisan key:generate --ansi

# ─── Step 9: Install Laravel Breeze ─────────────────────
info "Installing Laravel Breeze (authentication scaffold)..."
docker_exec composer require laravel/breeze --dev --no-interaction 2>/dev/null || true
echo "blade" | docker_exec php artisan breeze:install blade --no-interaction 2>/dev/null || \
    docker_exec php artisan breeze:install blade --no-interaction 2>/dev/null || true

# ─── Step 10: Run CRM installer ─────────────────────────
info "Running Laravel CRM installer..."
printf "blade\n" | docker_exec php artisan laravelcrm:install --no-interaction 2>/dev/null || true

# ─── Step 11: Migrations ───────────────────────────────
info "Running database migrations..."
docker_exec php artisan migrate --force

# ─── Step 12: CRM seeds (roles, permissions) ───────────
info "Seeding CRM roles and permissions..."
docker_exec php artisan db:seed --class="VentureDrake\\LaravelCrm\\Database\\Seeders\\RoleSeeder" --force 2>/dev/null || true
docker_exec php artisan db:seed --class="VentureDrake\\LaravelCrm\\Database\\Seeders\\PermissionSeeder" --force 2>/dev/null || true

# ─── Step 13: Create admin user ────────────────────────
info "Creating admin user..."
CRM_OWNER=$(grep LARAVEL_CRM_OWNER .env | cut -d= -f2)
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)

docker_exec php artisan tinker --execute="
    \$u = App\\Models\\User::firstOrCreate(['email' => '${CRM_OWNER}'], [
        'name' => 'Admin',
        'password' => bcrypt('${ADMIN_PASS}'),
    ]);
    \$role = VentureDrake\\LaravelCrm\\Models\\Role::where('name', 'Owner')->first();
    if (\$role) { \$u->assignRole(\$role); }
    echo 'User OK: ' . \$u->email;
"

# ─── Step 14: Fix permissions again ─────────────────────
info "Fixing storage permissions..."
docker_exec_root chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# ─── Step 15: Clear caches ──────────────────────────────
info "Clearing caches..."
docker_exec php artisan config:clear
docker_exec php artisan cache:clear
docker_exec php artisan view:clear
docker_exec php artisan route:clear

# ─── Step 16: Start all containers ──────────────────────
info "Starting all containers..."
$COMPOSE_CMD up -d

# ─── Step 17: Health check ──────────────────────────────
sleep 3
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm/login 2>/dev/null || echo "000")

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Laravel CRM deployed successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  CRM Login:  ${YELLOW}http://localhost:8080/crm/login${NC}"
echo -e "  Email:      ${YELLOW}${CRM_OWNER}${NC}"
echo -e "  Password:   ${YELLOW}${ADMIN_PASS}${NC}"
echo ""
echo -e "  ${RED}Save this password — it won't be shown again${NC}"
echo ""
echo -e "  Containers: ${YELLOW}$COMPOSE_CMD ps${NC}"
echo -e "  Logs:       ${YELLOW}$COMPOSE_CMD logs -f${NC}"
echo -e "  Stop:       ${YELLOW}$COMPOSE_CMD down${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [ "$HTTP_CODE" = "200" ]; then
    info "HTTP health check passed (200 OK)"
elif [ "$HTTP_CODE" = "000" ]; then
    warn "Could not reach localhost:8080 — check firewall settings"
else
    warn "HTTP health check returned ${HTTP_CODE} — check logs with: $COMPOSE_CMD logs -f"
fi
