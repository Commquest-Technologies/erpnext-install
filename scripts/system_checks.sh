#!/usr/bin/env bash
# System compatibility checks (root, OS, RAM)

system_checks() {
	log_info "Checking system compatibility..."

	if [ "$EUID" -eq 0 ]; then
		log_error "Please run as a regular user with sudo privileges, not as root"
		exit 1
	fi

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

	log_success "System checks passed"
}
