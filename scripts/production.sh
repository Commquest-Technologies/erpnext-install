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

	# Stop Apache if running (it holds port 80 and blocks nginx)
	if sudo systemctl is-active --quiet apache2 2>/dev/null; then
		log_info "Stopping Apache (conflicts with nginx on port 80)..."
		sudo systemctl stop apache2
		sudo systemctl disable apache2
	fi

	# Ensure nginx is installed and running before bench configures it
	safe_apt_install nginx
	sudo systemctl enable nginx
	sudo systemctl start nginx || true

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

	# Restart supervisor to ensure all bench processes (including Redis) are running
	log_info "Restarting supervisor processes..."
	sudo supervisorctl reread
	sudo supervisorctl update
	sudo supervisorctl restart all
	sleep 5

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
		log_info "Checking supervisor status..."
		sudo supervisorctl status || true
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
