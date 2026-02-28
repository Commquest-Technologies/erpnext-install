#!/usr/bin/env bash
# System update, user verification, and package installation (Python, Node, Yarn, Redis, MariaDB, uv)

install_system_packages() {
	log_info "Updating system packages..."
	sudo apt-get update -y
	sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

	log_info "Verifying user: $FRAPPE_USER"
	if id "$FRAPPE_USER" &>/dev/null; then
		log_success "User $FRAPPE_USER exists"
	else
		# User chose a different frappe user than the login user
		sudo adduser --disabled-password --gecos "" "$FRAPPE_USER"
		sudo usermod -aG sudo "$FRAPPE_USER"
		log_success "User $FRAPPE_USER created"
	fi

	# Ensure passwordless sudo (needed for bench setup production)
	if [ ! -f "/etc/sudoers.d/$FRAPPE_USER" ]; then
		echo "$FRAPPE_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$FRAPPE_USER" >/dev/null
		sudo chmod 440 "/etc/sudoers.d/$FRAPPE_USER"
		log_success "Passwordless sudo configured for $FRAPPE_USER"
	fi

	log_info "Installing system dependencies..."
	safe_apt_install git curl wget software-properties-common
	safe_apt_install build-essential libffi-dev libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev \
		libncursesw5-dev xz-utils tk-dev liblzma-dev

	if apt-cache show libmariadb-dev &>/dev/null; then
		safe_apt_install libmariadb-dev
	else
		safe_apt_install default-libmysqlclient-dev
	fi

	safe_apt_install libjpeg-dev libpng-dev libpq-dev
	safe_apt_install xvfb libfontconfig libfontconfig1
	_install_wkhtmltopdf
	_install_fonts
	safe_apt_install python3-pip python3-setuptools python3-venv pkg-config

	if ! command_exists pipx; then
		safe_apt_install pipx || {
			python3 -m pip install --user pipx
			python3 -m pipx ensurepath
		}
	fi

	_install_python
	_install_nodejs
	_install_yarn
	_install_redis
	_install_mariadb
	_install_uv
}

_install_wkhtmltopdf() {
	log_info "Installing wkhtmltopdf (patched Qt build)..."

	# Remove any existing apt version (wrong build, missing patched Qt)
	sudo apt-get remove --purge wkhtmltopdf -y 2>/dev/null || true

	# Detect Ubuntu codename for the correct .deb
	. /etc/os-release
	case "$VERSION_CODENAME" in
	focal) WKHTML_CODENAME="focal" ;;
	jammy) WKHTML_CODENAME="jammy" ;;
	noble) WKHTML_CODENAME="jammy" ;; # 24.04 uses the jammy build
	*) WKHTML_CODENAME="jammy" ;;     # default fallback
	esac

	local WKHTML_DEB="wkhtmltox_0.12.6.1-3.${WKHTML_CODENAME}_amd64.deb"
	local WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/${WKHTML_DEB}"

	wget -q -O "/tmp/${WKHTML_DEB}" "$WKHTML_URL" || {
		log_warn "Failed to download wkhtmltopdf - PDF generation may not work"
		return
	}

	sudo apt install -y "/tmp/${WKHTML_DEB}" || {
		sudo apt-get install -f -y
		sudo apt install -y "/tmp/${WKHTML_DEB}"
	}
	rm -f "/tmp/${WKHTML_DEB}"

	# Verify patched Qt build
	if wkhtmltopdf --version 2>&1 | grep -q "patched qt"; then
		log_success "wkhtmltopdf installed (patched Qt)"
	else
		log_warn "wkhtmltopdf installed but may not be the patched Qt build"
	fi
}

_install_fonts() {
	log_info "Installing fonts for PDF generation..."

	safe_apt_install fonts-liberation fonts-dejavu fonts-freefont-ttf \
		fontconfig libfontconfig1 fonts-open-sans fonts-roboto

	# Install Inter font (commonly used in ERPNext print formats)
	if ! fc-list | grep -qi "inter"; then
		log_info "Installing Inter font..."
		local INTER_URL="https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
		local INTER_TMP="/tmp/inter-font"
		mkdir -p "$INTER_TMP"
		wget -q -O "$INTER_TMP/inter.zip" "$INTER_URL" && {
			unzip -qo "$INTER_TMP/inter.zip" -d "$INTER_TMP"
			sudo mkdir -p /usr/share/fonts/inter
			find "$INTER_TMP" -name "*.ttf" -exec sudo cp {} /usr/share/fonts/inter/ \;
			rm -rf "$INTER_TMP"
			log_success "Inter font installed"
		} || log_warn "Failed to download Inter font - you can install it manually later"
	else
		log_success "Inter font already installed"
	fi

	sudo fc-cache -f -v >/dev/null 2>&1
	log_success "Font cache rebuilt"
}

_install_python() {
	log_info "Installing Python $PYTHON_VER..."

	if command_exists "python${PYTHON_VER}"; then
		log_success "Python $PYTHON_VER already installed"
	else
		if ! grep -q "deadsnakes" /etc/apt/sources.list.d/*.list 2>/dev/null; then
			sudo add-apt-repository -y ppa:deadsnakes/ppa
			sudo apt-get update -y
		fi
		safe_apt_install "python${PYTHON_VER}" "python${PYTHON_VER}-dev" "python${PYTHON_VER}-venv"
	fi

	PYTHON_BIN=$(which "python${PYTHON_VER}")
	if [ -z "$PYTHON_BIN" ]; then
		log_error "Python $PYTHON_VER not found after installation"
		exit 1
	fi
	log_success "Python: $PYTHON_BIN"
}

_install_nodejs() {
	log_info "Installing Node.js $NODE_VER..."

	install_nodejs() {
		log_info "Removing old Node.js installations..."
		sudo rm -f /etc/apt/sources.list.d/nodesource.list* 2>/dev/null || true
		sudo rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
		NODE_PKGS=$(dpkg -l | grep -E '^ii\s+(nodejs|npm|libnode)' | awk '{print $2}' | tr '\n' ' ') || true
		if [ -n "$NODE_PKGS" ]; then
			sudo apt-get remove -y --purge $NODE_PKGS 2>/dev/null || true
		fi
		sudo rm -rf /usr/include/node /usr/lib/node_modules 2>/dev/null || true
		sudo rm -f /usr/bin/node /usr/bin/nodejs /usr/bin/npm /usr/bin/npx 2>/dev/null || true
		sudo apt-get autoremove -y --purge 2>/dev/null || true
		sudo apt-get clean
		sudo apt-get update -y
		log_info "Installing Node.js $NODE_VER from NodeSource..."
		curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | sudo -E bash -
		sudo apt-get install -y nodejs
	}

	NEED_NODE=0
	if ! command_exists node; then
		NEED_NODE=1
	else
		CURRENT_NODE=$(node -v 2>/dev/null | cut -d. -f1 | tr -d v || echo "0")
		if [ "$CURRENT_NODE" -lt "$NODE_VER" ] 2>/dev/null; then
			NEED_NODE=1
		fi
	fi

	[ "$NEED_NODE" = "1" ] && install_nodejs

	if ! command_exists node; then
		log_error "Node.js installation failed"
		exit 1
	fi
	log_success "Node.js $(node -v)"
}

_install_yarn() {
	log_info "Installing Yarn..."
	sudo npm install -g npm@latest 2>/dev/null || true
	if ! command_exists yarn; then
		sudo npm install -g yarn
	fi
	# Clean up root's .yarnrc to avoid permission errors for non-root users
	sudo rm -f /root/.yarnrc 2>/dev/null || true
	log_success "Yarn installed"
}

_install_redis() {
	log_info "Installing Redis..."
	if ! command_exists redis-server; then
		safe_apt_install redis-server
	fi
	sudo systemctl enable redis-server 2>/dev/null || true
	sudo systemctl start redis-server 2>/dev/null || true
	if redis-cli ping &>/dev/null; then
		log_success "Redis is running"
	else
		log_warn "Redis may not be running properly"
	fi
}

_install_mariadb() {
	log_info "Installing MariaDB..."
	if ! command_exists mariadb; then
		safe_apt_install mariadb-server mariadb-client
	fi
	sudo systemctl enable mariadb
	sudo systemctl start mariadb

	# Verify MariaDB is actually running
	if sudo systemctl is-active --quiet mariadb; then
		log_success "MariaDB is running"
	else
		log_error "MariaDB failed to start"
		sudo systemctl status mariadb --no-pager || true
		exit 1
	fi
}

_install_uv() {
	log_info "Installing uv (Python package manager)..."

	# Install uv for the frappe user (bench requires it)
	sudo -u "$FRAPPE_USER" -H bash <<'UVINSTALL'
export PATH="$HOME/.local/bin:$PATH"
if command -v uv &>/dev/null; then
    echo "uv already installed: $(uv --version)"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
UVINSTALL

	log_success "uv installed"
}
