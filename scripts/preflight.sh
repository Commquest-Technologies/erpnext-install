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

		# If user exists, delete and recreate for a clean setup
		if id "$SETUP_USER" &>/dev/null; then
			log_warn "User '$SETUP_USER' already exists."
			log_info "Removing existing user '$SETUP_USER' for a clean install..."
			# Kill any running processes owned by this user
			pkill -u "$SETUP_USER" 2>/dev/null || true
			sleep 2
			# Remove user and home directory
			userdel -r "$SETUP_USER" 2>/dev/null || true
			rm -rf "/home/$SETUP_USER" 2>/dev/null || true
			# Remove old sudoers entry
			rm -f "/etc/sudoers.d/$SETUP_USER" 2>/dev/null || true
			log_success "User '$SETUP_USER' removed"
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
		SETUP_HOME="/home/$SETUP_USER"
		DEST_DIR="$SETUP_HOME/erpnext-install"

		if [ "$SCRIPT_DIR" != "$DEST_DIR" ]; then
			cp -r "$SCRIPT_DIR" "$DEST_DIR"
			chown -R "$SETUP_USER:$SETUP_USER" "$DEST_DIR"
		fi

		log_info "Re-launching installer as '$SETUP_USER'..."
		echo ""
		exec sudo -u "$SETUP_USER" -H bash "$DEST_DIR/frappe_installer.sh"
	fi

	log_success "System checks passed"
}
