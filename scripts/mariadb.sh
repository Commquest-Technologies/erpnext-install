#!/usr/bin/env bash
# MariaDB root password and Frappe-specific configuration

configure_mariadb() {
	log_info "Configuring MariaDB..."

	# Ensure MariaDB is running
	if ! sudo systemctl is-active --quiet mariadb; then
		log_info "Starting MariaDB..."
		sudo systemctl start mariadb
		sleep 2
	fi

	MYSQL_ROOT_PASS=""

	# Try socket authentication first (default on fresh installs)
	if sudo mysql -uroot -e "SELECT 1;" &>/dev/null; then
		log_success "MariaDB accessible (socket authentication)"

		read -p "Set a MariaDB root password? (recommended) [Y/n]: " SET_PASS
		SET_PASS=${SET_PASS:-Y}

		if [[ "$SET_PASS" =~ ^[Yy] ]]; then
			read -sp "Enter new MariaDB root password: " MYSQL_ROOT_PASS
			echo
			read -sp "Confirm password: " MYSQL_ROOT_PASS_CONFIRM
			echo
			if [ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS_CONFIRM" ]; then
				log_error "Passwords do not match"
				exit 1
			fi
			sudo mysql -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
SQL
			log_success "MariaDB root password set"
		else
			log_info "Using socket authentication (no password)"
		fi
	else
		# Socket auth didn't work — a root password is already set
		log_info "MariaDB root password is already set"
		while true; do
			read -sp "Enter MariaDB root password: " MYSQL_ROOT_PASS
			echo
			if sudo mysql -uroot -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" &>/dev/null; then
				log_success "Password verified"
				break
			else
				log_warn "Incorrect password"
				read -p "Try again? (y/n): " RETRY
				[ "$RETRY" != "y" ] && [ "$RETRY" != "Y" ] && exit 1
			fi
		done
	fi

	log_info "Applying MariaDB configuration..."
	sudo tee /etc/mysql/mariadb.conf.d/99-frappe.cnf >/dev/null <<'EOF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb_buffer_pool_size = 256M

[mysql]
default-character-set = utf8mb4
EOF

	if sudo systemctl restart mariadb; then
		log_success "MariaDB configured"
		sleep 2
	else
		log_warn "MariaDB restart failed"
		sudo rm -f /etc/mysql/mariadb.conf.d/99-frappe.cnf
		sudo systemctl restart mariadb
	fi
}
