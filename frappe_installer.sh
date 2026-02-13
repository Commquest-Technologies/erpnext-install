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
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/system_checks.sh"
source "$SCRIPTS_DIR/user_input.sh"
source "$SCRIPTS_DIR/system_packages.sh"
source "$SCRIPTS_DIR/mariadb_config.sh"
source "$SCRIPTS_DIR/bench_setup.sh"
source "$SCRIPTS_DIR/mode_production.sh"
source "$SCRIPTS_DIR/mode_dev.sh"
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
