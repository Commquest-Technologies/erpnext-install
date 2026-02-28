#!/usr/bin/env bash
# Print installation completion summary

print_summary() {
	SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

	echo ""
	echo "==========================================="
	echo "   INSTALLATION COMPLETE"
	echo "==========================================="
	echo ""
	echo "  Frappe     : $FRAPPE_VER ($FRAPPE_BRANCH)"
	echo "  Python     : $PYTHON_BIN"
	echo "  Node.js    : $(node -v)"
	echo "  Bench      : $BENCH_PATH"
	echo "  ERPNext    : ${INSTALL_ERPNEXT:-no}"
	echo ""
	if [ -n "$DOMAIN" ]; then
		if [ "$MULTI_TENANT" = "true" ]; then
			echo "  Sites:"
			IFS=',' read -ra DOMAIN_LIST <<< "$DOMAINS"
			for d in "${DOMAIN_LIST[@]}"; do
				d=$(echo "$d" | xargs)
				echo "    - https://$d"
			done
		else
			echo "  Site       : $SITE_NAME"
			echo "  URL        : https://$DOMAIN"
		fi
	else
		echo "  Site       : $SITE_NAME"
		echo "  URL        : http://$SERVER_IP:8000"
	fi
	echo ""
	echo "  Login:"
	echo "    Username : Administrator"
	echo "    Password : (the password you set during setup)"
	echo ""
	echo "==========================================="
	echo ""
	echo "Commands:"
	echo "  cd $BENCH_PATH"
	echo "  bench start                    # Dev mode"
	echo "  bench restart                  # Production"
	echo "  sudo supervisorctl status      # Check services"
	echo ""
}
