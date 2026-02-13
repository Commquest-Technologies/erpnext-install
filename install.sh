#!/usr/bin/env bash
###########################################
# Frappe/ERPNext Universal Installer
# Supports: Ubuntu 22.04, 24.04
###########################################

set -e
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Load modules
source "$SCRIPTS_DIR/utils.sh"
source "$SCRIPTS_DIR/preflight.sh"
source "$SCRIPTS_DIR/config.sh"
source "$SCRIPTS_DIR/packages.sh"
source "$SCRIPTS_DIR/mariadb.sh"
source "$SCRIPTS_DIR/bench.sh"
source "$SCRIPTS_DIR/production.sh"
source "$SCRIPTS_DIR/dev.sh"
source "$SCRIPTS_DIR/firewall.sh"
source "$SCRIPTS_DIR/summary.sh"

main() {
	system_checks
	collect_user_input
	install_system_packages
	configure_mariadb
	install_bench_and_site

	if [ -n "$DOMAIN" ]; then
		setup_production
	else
		setup_dev_mode
	fi

	configure_firewall
	print_summary
}

main "$@"
