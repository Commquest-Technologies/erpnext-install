#!/usr/bin/env bash
###########################################
# Add a new site to an existing Frappe bench
# Standalone helper for multi-tenant setups
###########################################

set -e
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

echo ""
echo "=========================================="
echo "   Add Site to Frappe Bench"
echo "=========================================="
echo ""

read -p "Enter Frappe system user [frappe]: " FRAPPE_USER
FRAPPE_USER=${FRAPPE_USER:-frappe}

read -p "Enter bench name [frappe-bench]: " BENCH_NAME
BENCH_NAME=${BENCH_NAME:-frappe-bench}

FRAPPE_HOME="/home/$FRAPPE_USER"
BENCH_PATH="$FRAPPE_HOME/$BENCH_NAME"

if [ ! -d "$BENCH_PATH" ]; then
	log_error "Bench not found at $BENCH_PATH"
	exit 1
fi

read -p "Enter new domain (e.g. newsite.example.com): " NEW_DOMAIN
if [ -z "$NEW_DOMAIN" ]; then
	log_error "Domain cannot be empty"
	exit 1
fi

read -sp "Enter admin password for the new site: " ADMIN_PASS
echo
if [ -z "$ADMIN_PASS" ]; then
	log_error "Admin password cannot be empty"
	exit 1
fi

read -sp "Enter MariaDB root password: " MYSQL_ROOT_PASS
echo
if [ -z "$MYSQL_ROOT_PASS" ]; then
	log_error "MariaDB root password cannot be empty"
	exit 1
fi

read -p "Install ERPNext on this site? [Y/n]: " INSTALL_CHOICE
INSTALL_CHOICE=${INSTALL_CHOICE:-Y}
INSTALL_ERPNEXT="no"
case "$INSTALL_CHOICE" in
[Yy]*) INSTALL_ERPNEXT="yes" ;;
esac

echo ""
log_info "Creating site: $NEW_DOMAIN"

# Create the new site
sudo -u "$FRAPPE_USER" -H env \
	"BENCH_PATH=$BENCH_PATH" \
	"NEW_DOMAIN=$NEW_DOMAIN" \
	"ADMIN_PASS=$ADMIN_PASS" \
	"MYSQL_ROOT_PASS=$MYSQL_ROOT_PASS" \
	"INSTALL_ERPNEXT=$INSTALL_ERPNEXT" \
	bash <<'ADDSITE'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"

# Clean up old DB if it exists
DB_NAME=$(echo "$NEW_DOMAIN" | tr '.' '_' | tr '-' '_')
mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP USER IF EXISTS '$DB_NAME'@'localhost';" 2>/dev/null || true

# Create the site
bench new-site "$NEW_DOMAIN" \
    --admin-password "$ADMIN_PASS" \
    --mariadb-root-password "$MYSQL_ROOT_PASS"

# Enable DNS multi-tenancy
bench config dns_multitenant on

# Install ERPNext if requested
if [ "$INSTALL_ERPNEXT" = "yes" ]; then
    bench --site "$NEW_DOMAIN" install-app erpnext
fi

bench --site "$NEW_DOMAIN" enable-scheduler
bench --site "$NEW_DOMAIN" set-maintenance-mode off
ADDSITE

log_success "Site $NEW_DOMAIN created"

# Regenerate nginx config and reload
log_info "Regenerating nginx configuration..."
PIPX_VENV_BIN="/home/$FRAPPE_USER/.local/share/pipx/venvs/frappe-bench/bin"
cd "$BENCH_PATH"
sudo env "PATH=$PIPX_VENV_BIN:/home/$FRAPPE_USER/.local/bin:$PATH" \
	bench setup nginx --yes
sudo systemctl reload nginx
log_success "Nginx reloaded"

# Get SSL certificate for the new domain
log_info "Setting up SSL for $NEW_DOMAIN..."
if sudo certbot --nginx -d "$NEW_DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null; then
	log_success "SSL certificate installed for $NEW_DOMAIN"
else
	log_warn "SSL setup failed. Run manually: sudo certbot --nginx -d $NEW_DOMAIN"
fi

echo ""
log_success "Site ready: https://$NEW_DOMAIN"
echo "  Login: Administrator / (password you set)"
echo ""
