#!/usr/bin/env bash
# Production setup: nginx, supervisor, ERPNext install, SSL

setup_production() {
	log_info "Setting up production..."

	# Build site list for multi-tenant support
	local ALL_SITES="$SITE_NAME"
	if [ "$MULTI_TENANT" = "true" ]; then
		ALL_SITES="$DOMAINS"
	fi

	# Enable scheduler and disable maintenance for all sites (run as frappe user)
	sudo -u "$FRAPPE_USER" -H env \
		"BENCH_PATH=$BENCH_PATH" \
		"ALL_SITES=$ALL_SITES" \
		bash <<'PRODSETUP'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
IFS=',' read -ra SITE_LIST <<< "$ALL_SITES"
for site in "${SITE_LIST[@]}"; do
    site=$(echo "$site" | xargs)
    bench --site "$site" enable-scheduler
    bench --site "$site" set-maintenance-mode off
done
PRODSETUP

	# Stop Apache if running (it holds port 80 and blocks nginx)
	if sudo systemctl is-active --quiet apache2 2>/dev/null; then
		log_info "Stopping Apache (conflicts with nginx on port 80)..."
		sudo systemctl stop apache2
		sudo systemctl disable apache2
	fi

	# Ensure nginx and supervisor are installed and running
	safe_apt_install nginx supervisor
	sudo systemctl enable nginx
	sudo systemctl restart nginx
	sudo systemctl enable supervisor
	sudo systemctl start supervisor

	# Fix file permissions so nginx (www-data) can read bench assets
	# Without this, CSS/JS files return 403 and the site appears unstyled
	log_info "Setting file permissions for nginx..."
	sudo usermod -a -G "$FRAPPE_USER" www-data
	sudo chmod o+rx "/home/$FRAPPE_USER"
	sudo chmod -R o+rx "$BENCH_PATH"

	# Setup production config (nginx + supervisor, requires sudo)
	# pipx isolates bench and its dependencies (including ansible) inside
	# ~/.local/share/pipx/venvs/frappe-bench/bin/ — we must add both that
	# directory and ~/.local/bin to PATH so sudo can find bench, ansible,
	# ansible-playbook, and all other binaries bench spawns internally
	PIPX_VENV_BIN="/home/$FRAPPE_USER/.local/share/pipx/venvs/frappe-bench/bin"
	cd "$BENCH_PATH"
	sudo env "PATH=$PIPX_VENV_BIN:/home/$FRAPPE_USER/.local/bin:$PATH" \
		"ANSIBLE_ALLOW_BROKEN_CONDITIONALS=true" \
		bench setup production "$FRAPPE_USER" --yes

	# Enable DNS multi-tenancy if multiple domains
	if [ "$MULTI_TENANT" = "true" ]; then
		log_info "Enabling DNS multi-tenancy..."
		sudo -u "$FRAPPE_USER" -H env \
			"BENCH_PATH=$BENCH_PATH" \
			bash <<'MULTITENANT'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
bench config dns_multitenant on
MULTITENANT

		# Regenerate nginx config for multi-tenant and reload
		sudo env "PATH=$PIPX_VENV_BIN:/home/$FRAPPE_USER/.local/bin:$PATH" \
			bench setup nginx --yes
		sudo systemctl reload nginx
		log_success "DNS multi-tenancy enabled"
	fi

	# Ensure supervisor config exists and is linked
	# bench setup production sometimes fails to create the symlink
	log_info "Verifying supervisor configuration..."
	BENCH_NAME=$(basename "$BENCH_PATH")
	SUPERVISOR_CONF="/etc/supervisor/conf.d/$BENCH_NAME.conf"

	if [ ! -f "$SUPERVISOR_CONF" ]; then
		log_warn "Supervisor config missing — generating manually..."

		# Generate supervisor config via bench
		sudo -u "$FRAPPE_USER" -H env \
			"BENCH_PATH=$BENCH_PATH" \
			bash <<'GENSUPERVISOR'
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
bench setup supervisor --yes
GENSUPERVISOR

		# Link it into supervisor's conf.d
		if [ -f "$BENCH_PATH/config/supervisor.conf" ]; then
			sudo ln -sf "$BENCH_PATH/config/supervisor.conf" "$SUPERVISOR_CONF"
			log_success "Supervisor config linked"
		else
			log_error "Failed to generate supervisor config"
		fi
	fi

	# Restart supervisor to ensure all bench processes (including Redis) are running
	log_info "Restarting supervisor processes..."
	sudo supervisorctl reread
	sudo supervisorctl update
	sudo supervisorctl restart all
	sleep 5

	# Verify supervisor processes are running
	log_info "Checking supervisor status..."
	sudo supervisorctl status || true

	# Read the actual Redis Queue port from bench config
	REDIS_QUEUE_PORT=$(python3 -c "
import json, re
conf = json.load(open('$BENCH_PATH/sites/common_site_config.json'))
m = re.search(r':(\d+)', conf.get('redis_queue', ''))
print(m.group(1) if m else '11000')
" 2>/dev/null || echo "11000")

	log_info "Waiting for Redis Queue (port $REDIS_QUEUE_PORT)..."
	for i in {1..30}; do
		if redis-cli -p "$REDIS_QUEUE_PORT" ping &>/dev/null; then
			log_success "Redis Queue is ready"
			break
		fi
		echo "  Waiting... ($i/30)"
		sleep 2
	done

	if ! redis-cli -p "$REDIS_QUEUE_PORT" ping &>/dev/null; then
		log_warn "Redis Queue on port $REDIS_QUEUE_PORT is not responding. ERPNext installation may fail."
	fi

	# Install ERPNext if requested — on all sites
	if [ "$INSTALL_ERPNEXT" = "yes" ]; then
		log_info "Installing ERPNext on site(s)..."
		sudo -u "$FRAPPE_USER" -H env \
			"BENCH_PATH=$BENCH_PATH" \
			"ALL_SITES=$ALL_SITES" \
			bash <<'ERPINSTALL'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
IFS=',' read -ra SITE_LIST <<< "$ALL_SITES"
for site in "${SITE_LIST[@]}"; do
    site=$(echo "$site" | xargs)
    echo "Installing ERPNext on $site..."
    bench --site "$site" install-app erpnext
done
ERPINSTALL
		log_success "ERPNext installed"
	else
		log_info "Skipping ERPNext installation (user chose not to install)"
	fi

	_setup_logrotate
	_setup_ssl
}

_setup_logrotate() {
	log_info "Setting up logrotate for bench logs..."
	cat <<EOF | sudo tee /etc/logrotate.d/frappe-bench >/dev/null
$BENCH_PATH/logs/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
	log_success "Logrotate configured"
}

_setup_ssl() {
	log_info "Setting up SSL certificate..."
	sudo snap install core 2>/dev/null || true
	sudo snap refresh core 2>/dev/null || true
	sudo snap install --classic certbot 2>/dev/null || true
	sudo ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true

	# Build domain flags for certbot
	local CERTBOT_DOMAINS=""
	if [ "$MULTI_TENANT" = "true" ]; then
		IFS=',' read -ra DOMAIN_LIST <<< "$DOMAINS"
		for d in "${DOMAIN_LIST[@]}"; do
			d=$(echo "$d" | xargs)
			CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d $d"
		done
	else
		CERTBOT_DOMAINS="-d $DOMAIN"
	fi

	if sudo certbot --nginx $CERTBOT_DOMAINS --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null; then
		log_success "SSL certificate installed"

		# Verify auto-renewal is working
		if sudo certbot renew --dry-run 2>/dev/null; then
			log_success "SSL auto-renewal verified"
		else
			log_warn "SSL auto-renewal dry-run failed. Check: sudo certbot renew --dry-run"
		fi
	else
		log_warn "SSL setup failed. Run manually: sudo certbot --nginx $CERTBOT_DOMAINS"
	fi
}
