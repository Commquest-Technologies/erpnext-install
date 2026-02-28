#!/usr/bin/env bash
# Collect installation configuration from user

collect_user_input() {
	echo ""
	echo "=========================================="
	echo "   Frappe/ERPNext Installation Wizard"
	echo "=========================================="
	echo ""

	read -p "Enter Frappe version (15 or 16) [16]: " FRAPPE_VER
	FRAPPE_VER=${FRAPPE_VER:-16}
	if [ "$FRAPPE_VER" != "15" ] && [ "$FRAPPE_VER" != "16" ]; then
		log_error "Invalid version. Enter 15 or 16"
		exit 1
	fi

	read -p "Enter system user for Frappe [frappe]: " FRAPPE_USER
	FRAPPE_USER=${FRAPPE_USER:-frappe}

	read -p "Enter bench name [frappe-bench]: " BENCH_NAME
	BENCH_NAME=${BENCH_NAME:-frappe-bench}

	# Domain(s) — ask before site name so we can auto-set it
	echo ""
	echo "Enter domain(s), comma-separated (leave empty for dev mode)."
	echo "  Single domain  : example.com"
	echo "  Multi-tenant   : site1.com,site2.com,site3.com"
	read -p "Domain(s): " DOMAIN_INPUT

	MULTI_TENANT="false"
	DOMAINS=""
	DOMAIN=""

	if [ -n "$DOMAIN_INPUT" ]; then
		# Trim spaces around commas and set variables
		DOMAINS=$(echo "$DOMAIN_INPUT" | sed 's/ *, */,/g')
		# First domain is the primary
		DOMAIN=$(echo "$DOMAINS" | cut -d',' -f1)

		# Check if multi-tenant (more than one domain)
		local DOMAIN_COUNT
		DOMAIN_COUNT=$(echo "$DOMAINS" | tr ',' '\n' | wc -l | xargs)
		if [ "$DOMAIN_COUNT" -gt 1 ]; then
			MULTI_TENANT="true"
		fi

		# Auto-set site name to primary domain
		SITE_NAME="$DOMAIN"
		log_info "Primary site set to: $SITE_NAME"
	else
		read -p "Enter site name: " SITE_NAME
		if [ -z "$SITE_NAME" ]; then
			log_error "Site name cannot be empty"
			exit 1
		fi
	fi

	read -sp "Enter admin password: " ADMIN_PASS
	echo
	if [ -z "$ADMIN_PASS" ]; then
		log_error "Admin password cannot be empty"
		exit 1
	fi

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
	if [ -n "$DOMAIN" ]; then
		if [ "$MULTI_TENANT" = "true" ]; then
			echo "  Domains        : $DOMAINS (Multi-tenant)"
		else
			echo "  Domain         : $DOMAIN (Production)"
		fi
	else
		echo "  Mode           : Development"
	fi
	echo ""

	read -p "Continue with these settings? [Y/n]: " CONFIRM
	CONFIRM=${CONFIRM:-Y}
	if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
		log_info "Installation cancelled"
		exit 0
	fi
}
