#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || error "Docker is required. Install it first."

COMPOSE_CMD="docker compose"
if ! docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
fi

docker_exec_root() { $COMPOSE_CMD exec -T -u root app "$@"; }
docker_exec() { $COMPOSE_CMD exec -T app "$@"; }

# ─── Step 1: Environment file ───────────────────────────
info "Setting up environment..."
ENV_DIR="./app"
APP_DIR="./app"

if [ ! -f "${ENV_DIR}/.env" ]; then
  cp ".env.example" "${ENV_DIR}/.env"
  info "Created ${ENV_DIR}/.env from .env.example"
else
  warn "${ENV_DIR}/.env already exists — skipping creation"
fi

# ─── Step 2: Generate secure passwords ──────────────────
if grep -q "CHANGE_ME" "${APP_DIR}/.env" 2>/dev/null; then
  DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
  ROOT_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)

  sed -i "s|CHANGE.*DB_PASSWORD_HERE|${DB_PASS}|g" "${APP_DIR}/.env"
  sed -i "s|CHANGE.*ROOT_PASSWORD_HERE|${ROOT_PASS}|g" "${APP_DIR}/.env"

  sed -i "s|crm_pass_2026|${DB_PASS}|g" docker-compose.yml
  sed -i "s|crm_root_2026|${ROOT_PASS}|g" docker-compose.yml

  info "Generated secure DB credentials"
else
  DB_PASS=$(grep "^DB_PASSWORD=" "${APP_DIR}/.env" | cut -d= -f2 || echo "")
  warn "Credentials already set in ${APP_DIR}/.env — skipping"
fi

CRM_OWNER=$(grep "^LARAVEL_CRM_OWNER=" "${APP_DIR}/.env" | cut -d= -f2 | tr -d '[:space:]')
info "CRM Owner: ${CRM_OWNER}"

# ─── Step 2b: Sync DB config ────────────────────────────
info "Ensuring DB config is correct..."
sed -i '/^DB_CONNECTION=/d' "${APP_DIR}/.env"
sed -i '/^DB_HOST=/d' "${APP_DIR}/.env"
sed -i '/^DB_PORT=/d' "${APP_DIR}/.env"
sed -i '/^DB_DATABASE=/d' "${APP_DIR}/.env"
sed -i '/^DB_USERNAME=/d' "${APP_DIR}/.env"
sed -i '/^DB_PASSWORD=/d' "${APP_DIR}/.env"

FINAL_DB_PASS="${DB_PASS:-crm_pass_2026}"

cat >>"${APP_DIR}/.env" <<DBEOF
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=laravel_crm
DB_USERNAME=crm_user
DB_PASSWORD=${FINAL_DB_PASS}
DBEOF

# FIX: Sincronizar password en docker-compose.yml también
sed -i "s|MARIADB_PASSWORD:.*|MARIADB_PASSWORD: ${FINAL_DB_PASS}|g" docker-compose.yml
FINAL_ROOT_PASS=$(grep "^MARIADB_ROOT_PASSWORD=" "${APP_DIR}/.env" | cut -d= -f2)
sed -i "s|MARIADB_ROOT_PASSWORD:.*|MARIADB_ROOT_PASSWORD: ${FINAL_ROOT_PASS}|g" docker-compose.yml
info "DB config set:"
grep "^DB_" "${APP_DIR}/.env"

# ─── Step 3: Build Docker image ─────────────────────────
info "Building PHP-FPM Docker image (this may take a few minutes)..."
$COMPOSE_CMD build app

# ─── Step 4: Start database ─────────────────────────────
info "Starting database..."
$COMPOSE_CMD up -d db
sleep 5

info "Waiting for database to be ready..."
RETRIES=30
until $COMPOSE_CMD exec -T db mysqladmin ping -h localhost -u root --silent 2>/dev/null; do
  RETRIES=$((RETRIES - 1))
  [ $RETRIES -le 0 ] && error "Database failed to start after 30 retries"
  sleep 2
done
info "Database is ready"

# ─── Step 4b: Verify DB credentials match .env ──────────
info "Verifying DB credentials match .env..."
if ! $COMPOSE_CMD exec -T db mysql -uroot -p"${FINAL_ROOT_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
  warn "Root password in .env does NOT match the existing database volume."
  warn "This usually happens when the volume 'crm_db_data' already existed from a previous deploy —"
  warn "MariaDB only applies MARIADB_ROOT_PASSWORD/MARIADB_PASSWORD when the volume is first created."
  echo ""
  echo -e "  ${YELLOW}Options:${NC}"
  echo -e "   1) If this is a fresh/test environment with no data to keep, run:"
  echo -e "      ${YELLOW}${COMPOSE_CMD} down && docker volume rm laravel-crm_crm_db_data && ./deploy.sh${NC}"
  echo -e "   2) If you need to keep existing data, manually sync the password:"
  echo -e "      ${YELLOW}docker exec -it crm-db mysql -uroot -p<OLD_ROOT_PASSWORD>${NC}"
  echo -e "      ${YELLOW}ALTER USER 'crm_user'@'%' IDENTIFIED BY '${FINAL_DB_PASS}';${NC}"
  echo -e "      ${YELLOW}ALTER USER 'root'@'localhost' IDENTIFIED BY '${FINAL_ROOT_PASS}';${NC}"
  echo -e "      ${YELLOW}FLUSH PRIVILEGES;${NC}"
  error "Aborting deploy — credentials mismatch must be resolved first."
else
  info "DB credentials verified OK"
fi

# ─── Step 5: Start app container ────────────────────────
info "Starting app container..."
$COMPOSE_CMD up -d app
sleep 3

# ─── Step 6: Install Composer dependencies ──────────────
info "Installing Composer dependencies..."
docker_exec_root composer install --no-interaction --optimize-autoloader

# ─── Step 7: Fix permissions ────────────────────────────
info "Fixing storage permissions..."
docker_exec_root mkdir -p \
  /var/www/html/storage/framework/views \
  /var/www/html/storage/framework/sessions \
  /var/www/html/storage/framework/cache/data \
  /var/www/html/storage/framework/testing \
  /var/www/html/storage/logs \
  /var/www/html/storage/tmp \
  /var/www/html/bootstrap/cache
docker_exec_root chown -R www-data:www-data \
  /var/www/html/storage \
  /var/www/html/bootstrap/cache

# ─── Step 8: Generate APP_KEY ───────────────────────────
info "Generating application key..."
docker_exec php artisan key:generate --ansi

# ─── Step 9: Install Laravel Breeze ─────────────────────
info "Installing Laravel Breeze..."
docker_exec composer require laravel/breeze --dev --no-interaction 2>/dev/null || true
echo "blade" | docker_exec php artisan breeze:install blade --no-interaction 2>/dev/null ||
  docker_exec php artisan breeze:install blade --no-interaction 2>/dev/null || true

# ─── Step 9b: Inject Custom CRM Webhook Routes ──────────
if ! grep -q "crm/webhooks" "${APP_DIR}/routes/web.php" 2>/dev/null; then
  info "Injecting CRM Webhook routes into web.php..."
  cat >>"${APP_DIR}/routes/web.php" <<'WEBHOOKEOF'

// Webhooks
Route::middleware(['auth'])->prefix('crm')->group(function () {
    Route::get('/webhooks', [App\Http\Controllers\WebhookController::class, 'index'])
        ->name('crm.webhooks.index');
});
WEBHOOKEOF
else
  info "CRM Webhook routes already exist in web.php — skipping injection"
fi

# ─── Step 10: Run migrations ────────────────────────────
info "Running database migrations..."
docker_exec php artisan migrate --force

# ─── Step 11: Run CRM installer ─────────────────────────
info "Running Laravel CRM installer..."
ADMIN_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
CRM_OWNER=$(grep "^LARAVEL_CRM_OWNER=" "${ENV_DIR}/.env" | cut -d= -f2 | tr -d '[:space:]')

printf "yes\n" | docker_exec php artisan laravelcrm:install 2>&1 ||
  warn "CRM installer reported an error — continuing anyway..."

# ─── Step 12: CRM seeds (roles, permissions, pipelines) ─
# FIX: Seeders ANTES de crear el usuario para que el rol exista
info "Seeding CRM roles and permissions..."
docker_exec php artisan db:seed \
  --class="VentureDrake\\LaravelCrm\\Database\\Seeders\\LaravelCrmTablesSeeder" \
  --force 2>/dev/null || warn "LaravelCrmTablesSeeder failed"
docker_exec php artisan db:seed \
  --class="VentureDrake\\LaravelCrm\\Database\\Seeders\\LaravelCrmPipelineTablesSeeder" \
  --force 2>/dev/null || warn "LaravelCrmPipelineTablesSeeder failed"

# ─── Step 13: Create owner user ─────────────────────────
info "Ensuring CRM owner user exists..."
docker_exec php artisan tinker --execute="
    \$u = App\\Models\\User::firstOrCreate(
        ['email' => '${CRM_OWNER}'],
        ['name' => 'Admin', 'password' => bcrypt('${ADMIN_PASS}')]
    );
    \$u->password = bcrypt('${ADMIN_PASS}');
    \$u->save();
    \$role = Spatie\\Permission\\Models\\Role::where('name', 'owner')->first();
    if (\$role && !\$u->hasRole('owner')) { \$u->assignRole(\$role); }
    echo \$u->email;
" 2>/dev/null && info "CRM owner ready: ${CRM_OWNER}" || warn "Could not verify user"

# ─── Step 14: Fix permissions again ─────────────────────
info "Fixing storage permissions..."
docker_exec_root chown -R www-data:www-data \
  /var/www/html/storage \
  /var/www/html/bootstrap/cache

# ─── Step 15: Clear caches ──────────────────────────────
info "Clearing caches..."
docker_exec php artisan config:clear
docker_exec php artisan cache:clear
docker_exec php artisan view:clear
docker_exec php artisan route:clear

# ─── Step 16: Start all containers ──────────────────────
info "Starting all containers..."
$COMPOSE_CMD up -d || error "Failed to start containers"
sleep 3
docker compose ps

# ─── Step 17: Health check ──────────────────────────────
sleep 3
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm/login 2>/dev/null || echo "000")

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Laravel CRM deployed successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
FINAL_OWNER=$(grep "^LARAVEL_CRM_OWNER=" "./app/.env" | cut -d= -f2 | tr -d '[:space:]')
echo -e "  CRM Login:  ${YELLOW}http://localhost:8080/crm/login${NC}"
echo -e "  Email/User: ${YELLOW}${FINAL_OWNER}${NC}"
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
