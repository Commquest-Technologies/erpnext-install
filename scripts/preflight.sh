#!/usr/bin/env bash
# Pre-flight checks: OS detection, RAM check, root-to-user handoff

system_checks() {
	log_info "Checking system compatibility..."

	# Detect OS
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		if [ "$ID" != "ubuntu" ]; then
			log_warn "This script is designed for Ubuntu. Detected: $ID"
		fi
		log_info "Detected: $PRETTY_NAME"
	else
		log_warn "Cannot detect OS version"
	fi

	TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
	if [ "$TOTAL_MEM" -lt 2048 ]; then
		log_warn "System has ${TOTAL_MEM}MB RAM. Minimum 4GB recommended"
	fi

	# If running as root, create a non-root user and re-launch as that user
	if [ "$EUID" -eq 0 ]; then
		log_warn "Running as root. A non-root user is required for Frappe."
		echo ""
		read -p "Enter username to create [frappe]: " SETUP_USER
		SETUP_USER=${SETUP_USER:-frappe}

		SETUP_HOME="/home/$SETUP_USER"
		DEST_DIR="$SETUP_HOME/erpnext-install"

		if id "$SETUP_USER" &>/dev/null; then
			log_warn "User '$SETUP_USER' already exists."
			echo ""
			read -p "Reuse existing user and continue? [Y/n]: " REUSE_USER
			REUSE_USER=${REUSE_USER:-Y}

			if [ "$REUSE_USER" = "n" ] || [ "$REUSE_USER" = "N" ]; then
				log_info "Removing existing user '$SETUP_USER' for a clean install..."

				# Drop any existing site databases from MariaDB before wiping files
				_cleanup_site_databases "$SETUP_USER"

				# Kill any running processes owned by this user
				pkill -u "$SETUP_USER" 2>/dev/null || true
				sleep 2
				# Remove user and home directory
				userdel -r "$SETUP_USER" 2>/dev/null || true
				rm -rf "$SETUP_HOME" 2>/dev/null || true
				# Remove old sudoers entry
				rm -f "/etc/sudoers.d/$SETUP_USER" 2>/dev/null || true
				log_success "User '$SETUP_USER' removed"
			else
				log_info "Reusing existing user '$SETUP_USER'"

				# Ensure passwordless sudo
				if [ ! -f "/etc/sudoers.d/$SETUP_USER" ]; then
					echo "$SETUP_USER ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/$SETUP_USER" >/dev/null
					chmod 440 "/etc/sudoers.d/$SETUP_USER"
				fi

				# Copy installer and re-launch
				if [ "$SCRIPT_DIR" != "$DEST_DIR" ]; then
					rm -rf "$DEST_DIR" 2>/dev/null || true
					cp -r "$SCRIPT_DIR" "$DEST_DIR"
					chown -R "$SETUP_USER:$SETUP_USER" "$DEST_DIR"
				fi

				log_info "Re-launching installer as '$SETUP_USER'..."
				echo ""
				exec sudo -u "$SETUP_USER" -H bash "$DEST_DIR/install.sh"
			fi
		fi

		log_info "Creating user '$SETUP_USER'..."
		adduser --disabled-password --gecos "" "$SETUP_USER"
		usermod -aG sudo "$SETUP_USER"
		echo ""
		log_info "Set a login password for '$SETUP_USER':"
		passwd "$SETUP_USER"
		log_success "User $SETUP_USER created with sudo access"

		# Passwordless sudo for the installation
		echo "$SETUP_USER ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/$SETUP_USER" >/dev/null
		chmod 440 "/etc/sudoers.d/$SETUP_USER"

		# Copy the installer to the user's home and re-launch
		if [ "$SCRIPT_DIR" != "$DEST_DIR" ]; then
			cp -r "$SCRIPT_DIR" "$DEST_DIR"
			chown -R "$SETUP_USER:$SETUP_USER" "$DEST_DIR"
		fi

		log_info "Re-launching installer as '$SETUP_USER'..."
		echo ""
		exec sudo -u "$SETUP_USER" -H bash "$DEST_DIR/install.sh"
	fi

	log_success "System checks passed"
}

_cleanup_site_databases() {
	local USER=$1
	local USER_HOME="/home/$USER"

	# Find site_config.json files in any bench installation
	for site_config in "$USER_HOME"/*/sites/*/site_config.json; do
		[ -f "$site_config" ] || continue
		local DB_NAME
		DB_NAME=$(python3 -c "import json; print(json.load(open('$site_config')).get('db_name',''))" 2>/dev/null) || continue
		if [ -n "$DB_NAME" ]; then
			log_info "Dropping database: $DB_NAME"
			sudo mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
			sudo mysql -uroot -e "DROP USER IF EXISTS '$DB_NAME'@'localhost';" 2>/dev/null || true
		fi
	done
}
