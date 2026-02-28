#!/usr/bin/env bash
# UFW firewall configuration and fail2ban

configure_firewall() {
	if command_exists ufw; then
		log_info "Configuring firewall..."
		sudo ufw allow 22,80,443,8000/tcp
		sudo ufw --force enable
		log_success "Firewall configured"
	fi

	_setup_fail2ban
}

_setup_fail2ban() {
	log_info "Setting up fail2ban..."
	safe_apt_install fail2ban

	sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
EOF

	sudo systemctl enable fail2ban
	sudo systemctl restart fail2ban
	log_success "fail2ban configured"
}
