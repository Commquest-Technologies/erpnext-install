#!/usr/bin/env bash
# Bench CLI install, bench init, site creation, optional ERPNext download

install_bench_and_site() {
	log_info "Installing Frappe Bench..."

	sudo -u "$FRAPPE_USER" -H bash <<'BENCHINSTALL'
set -e
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath 2>/dev/null || true
if ! command -v bench &>/dev/null; then
    pipx install frappe-bench || pip3 install --user frappe-bench
fi
bench --version
BENCHINSTALL

	log_success "Bench installed"

	log_info "Initializing Bench..."

	# Pass all variables via env to avoid heredoc double-expansion issues
	# (passwords with $, !, `, \ etc. would get corrupted in unquoted heredocs)
	sudo -u "$FRAPPE_USER" -H env \
		"FRAPPE_HOME=$FRAPPE_HOME" \
		"BENCH_PATH=$BENCH_PATH" \
		"PYTHON_BIN=$PYTHON_BIN" \
		"FRAPPE_BRANCH=$FRAPPE_BRANCH" \
		"FRAPPE_VER=$FRAPPE_VER" \
		"SITE_NAME=$SITE_NAME" \
		"ADMIN_PASS=$ADMIN_PASS" \
		"MYSQL_ROOT_PASS=$MYSQL_ROOT_PASS" \
		"DOMAINS=$DOMAINS" \
		"MULTI_TENANT=$MULTI_TENANT" \
		bash <<'BENCHINIT'
set -e
export PATH="$HOME/.local/bin:$PATH"

cd "$FRAPPE_HOME"

if [ ! -d "$BENCH_PATH" ]; then
    bench init "$BENCH_PATH" \
        --python "$PYTHON_BIN" \
        --frappe-branch "$FRAPPE_BRANCH"
else
    echo "Bench directory already exists at $BENCH_PATH"
fi

cd "$BENCH_PATH"

if [ "$FRAPPE_VER" = "15" ]; then
    ./env/bin/pip install --upgrade pip
    ./env/bin/pip install "setuptools>=58,<75"
fi

# Create primary site
if [ ! -d "sites/$SITE_NAME" ]; then
    # Drop leftover database from a previous install (user was deleted but DB remains)
    DB_NAME=$(echo "$SITE_NAME" | tr '.' '_' | tr '-' '_')
    if [ -n "$MYSQL_ROOT_PASS" ]; then
        mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
        mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP USER IF EXISTS '$DB_NAME'@'localhost';" 2>/dev/null || true
        bench new-site "$SITE_NAME" \
            --admin-password "$ADMIN_PASS" \
            --mariadb-root-password "$MYSQL_ROOT_PASS"
    else
        bench new-site "$SITE_NAME" \
            --admin-password "$ADMIN_PASS"
    fi
fi

bench use "$SITE_NAME"

# Create additional sites for multi-tenant setup
if [ "$MULTI_TENANT" = "true" ] && [ -n "$DOMAINS" ]; then
    IFS=',' read -ra DOMAIN_LIST <<< "$DOMAINS"
    for domain in "${DOMAIN_LIST[@]}"; do
        domain=$(echo "$domain" | xargs)
        # Skip the primary site (already created)
        [ "$domain" = "$SITE_NAME" ] && continue

        echo "Creating additional site: $domain"
        if [ ! -d "sites/$domain" ]; then
            DB_NAME=$(echo "$domain" | tr '.' '_' | tr '-' '_')
            if [ -n "$MYSQL_ROOT_PASS" ]; then
                mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
                mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP USER IF EXISTS '$DB_NAME'@'localhost';" 2>/dev/null || true
                bench new-site "$domain" \
                    --admin-password "$ADMIN_PASS" \
                    --mariadb-root-password "$MYSQL_ROOT_PASS"
            else
                bench new-site "$domain" \
                    --admin-password "$ADMIN_PASS"
            fi
        fi
    done
fi
BENCHINIT

	log_success "Bench initialized and site(s) created"

	# Only download ERPNext if user chose to install it
	if [ "$INSTALL_ERPNEXT" = "yes" ]; then
		log_info "Downloading ERPNext..."
		sudo -u "$FRAPPE_USER" -H env \
			"BENCH_PATH=$BENCH_PATH" \
			"FRAPPE_BRANCH=$FRAPPE_BRANCH" \
			bash <<'GETERPNEXT'
set -e
export PATH="$HOME/.local/bin:$PATH"
cd "$BENCH_PATH"
if [ ! -d "apps/erpnext" ]; then
    bench get-app erpnext --branch "$FRAPPE_BRANCH"
fi
GETERPNEXT
		log_success "ERPNext downloaded"
	fi
}
