#!/usr/bin/env bash
# Collect user input and set version-specific variables

collect_user_input() {
	echo ""
	echo "=========================================="
	echo "   Frappe/ERPNext Installation Wizard"
	echo "=========================================="
	echo ""

	read -p "Enter Frappe version (15 or 16): " FRAPPE_VER
	if [ "$FRAPPE_VER" != "15" ] && [ "$FRAPPE_VER" != "16" ]; then
		log_error "Invalid version. Enter 15 or 16"
		exit 1
	fi

	read -p "Enter system user for Frappe [frappe]: " FRAPPE_USER
	FRAPPE_USER=${FRAPPE_USER:-frappe}

	read -p "Enter bench name [frappe-bench]: " BENCH_NAME
	BENCH_NAME=${BENCH_NAME:-frappe-bench}

	read -p "Enter site name: " SITE_NAME
	if [ -z "$SITE_NAME" ]; then
		log_error "Site name cannot be empty"
		exit 1
	fi

	read -sp "Enter admin password: " ADMIN_PASS
	echo
	if [ -z "$ADMIN_PASS" ]; then
		log_error "Admin password cannot be empty"
		exit 1
	fi

	read -p "Enter domain (leave empty for dev mode): " DOMAIN

	if [ "$FRAPPE_VER" = "15" ]; then
		PYTHON_VER="3.10"
		FRAPPE_BRANCH="version-15"
		NODE_VER="24"
	else
		PYTHON_VER="3.14"
		FRAPPE_BRANCH="version-16"
		NODE_VER="24"
	fi

	FRAPPE_HOME="/home/$FRAPPE_USER"
	BENCH_PATH="$FRAPPE_HOME/$BENCH_NAME"

	# Ask about ERPNext during input collection
	echo ""
	read -p "Install ERPNext app? [Y/n]: " INSTALL_CHOICE
	INSTALL_CHOICE=${INSTALL_CHOICE:-Y}
	case "$INSTALL_CHOICE" in
	[Yy]*) INSTALL_ERPNEXT="yes" ;;
	*) INSTALL_ERPNEXT="no" ;;
	esac

	echo ""
	log_info "Configuration Summary:"
	echo "  Frappe Version : $FRAPPE_VER ($FRAPPE_BRANCH)"
	echo "  Python         : $PYTHON_VER"
	echo "  Node.js        : $NODE_VER"
	echo "  User           : $FRAPPE_USER"
	echo "  Bench Path     : $BENCH_PATH"
	echo "  Site           : $SITE_NAME"
	echo "  ERPNext        : $INSTALL_ERPNEXT"
	[ -n "$DOMAIN" ] && echo "  Domain         : $DOMAIN (Production)" || echo "  Mode           : Development"
	echo ""

	read -p "Continue with these settings? [Y/n]: " CONFIRM
	CONFIRM=${CONFIRM:-Y}
	if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
		log_info "Installation cancelled"
		exit 0
	fi
}
