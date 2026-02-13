#!/usr/bin/env bash
# Production setup: nginx, supervisor, ERPNext install, SSL

setup_production() {
	log_info "Setting up production..."

	# Enable scheduler and disable maintenance (run as frappe user)
	sudo -u "$FRAPPE_USER" -H env \
		"BENCH_PATH=$BENCH_PATH" \
		"SITE_NAME=$SITE_NAME" \
		bash <<'PRODSETUP'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
bench --site "$SITE_NAME" enable-scheduler
bench --site "$SITE_NAME" set-maintenance-mode off
PRODSETUP

	# Setup production config (nginx + supervisor, requires sudo)
	cd "$BENCH_PATH"
	sudo bench setup production "$FRAPPE_USER" --yes

	# Wait for Redis Queue before installing apps
	log_info "Waiting for Redis Queue (port 11001)..."
	for i in {1..30}; do
		if redis-cli -p 11001 ping &>/dev/null; then
			log_success "Redis Queue is ready"
			break
		fi
		echo "  Waiting... ($i/30)"
		sleep 2
	done

	if ! redis-cli -p 11001 ping &>/dev/null; then
		log_warn "Redis Queue on port 11001 is not responding. ERPNext installation may fail."
	fi

	# Install ERPNext if requested
	if [ "$INSTALL_ERPNEXT" = "yes" ]; then
		log_info "Installing ERPNext on site..."
		sudo -u "$FRAPPE_USER" -H env \
			"BENCH_PATH=$BENCH_PATH" \
			"SITE_NAME=$SITE_NAME" \
			bash <<'ERPINSTALL'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
bench --site "$SITE_NAME" install-app erpnext
ERPINSTALL
		log_success "ERPNext installed"
	else
		log_info "Skipping ERPNext installation (user chose not to install)"
	fi

	_setup_ssl
}

_setup_ssl() {
	log_info "Setting up SSL certificate..."
	sudo snap install core 2>/dev/null || true
	sudo snap refresh core 2>/dev/null || true
	sudo snap install --classic certbot 2>/dev/null || true
	sudo ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true

	if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null; then
		log_success "SSL certificate installed"
	else
		log_warn "SSL setup failed. Run manually: sudo certbot --nginx -d $DOMAIN"
	fi
}
