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

	# Try socket auth (works on fresh installs where root uses unix_socket)
	if sudo mysql -uroot -e "SELECT 1;" &>/dev/null; then
		log_success "MariaDB accessible (socket authentication)"
		log_info "A MariaDB root password is required for Frappe/ERPNext."
		echo ""

		read -sp "Enter new MariaDB root password: " MYSQL_ROOT_PASS
		echo
		read -sp "Confirm password: " MYSQL_ROOT_PASS_CONFIRM
		echo

		if [ -z "$MYSQL_ROOT_PASS" ]; then
			log_error "Password cannot be empty"
			exit 1
		fi

		if [ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS_CONFIRM" ]; then
			log_error "Passwords do not match"
			exit 1
		fi

		# Switch root to mysql_native_password so bench can connect without sudo
		sudo mysql -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$MYSQL_ROOT_PASS') OR unix_socket;
FLUSH PRIVILEGES;
SQL

		# Verify password works WITHOUT sudo (this is how bench connects)
		if mysql -uroot -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" &>/dev/null; then
			log_success "MariaDB root password set and verified"
		else
			log_error "MariaDB password verification failed. bench will not be able to connect."
			exit 1
		fi
	else
		# Socket auth failed — a root password is already set
		log_info "MariaDB root password detected"
		while true; do
			read -sp "Enter MariaDB root password: " MYSQL_ROOT_PASS
			echo
			# Verify WITHOUT sudo — this is how bench actually connects
			if mysql -uroot -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" &>/dev/null; then
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
