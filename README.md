# Frappe/ERPNext Automated Installer (v15 and v16)

A modular bash installer for **Frappe Framework** and **ERPNext** on Ubuntu systems. Supports Frappe **v15** and **v16** with version 16 as the default.

## Features

- **Version selection** — Frappe v15 (Python 3.10) or v16 (Python 3.14), defaults to v16
- **Root-safe execution** — Run as root on a fresh VPS; the script creates a non-root user, sets a login password, and re-launches itself automatically
- **Re-run friendly** — Detects existing users and offers to reuse or start fresh (cleans up databases on fresh start)
- **Full dependency stack** — Node.js 24, Yarn, Redis, MariaDB, uv, pipx, Ansible
- **MariaDB auto-detection** — Detects fresh installs vs existing passwords, configures `mysql_native_password` for bench compatibility
- **Optional ERPNext** — Install only the Frappe framework, or include ERPNext
- **Production-ready** — Nginx, Supervisor, file permissions, SSL via Let's Encrypt
- **Firewall configuration** — UFW rules for ports 22, 80, 443, and 8000
- **Confirmation prompt** — Review all settings before installation begins

## Prerequisites

- **Operating system**: Ubuntu 22.04 or 24.04 (fresh installation recommended)
- **RAM**: Minimum 4 GB (8 GB recommended for production)
- **Storage**: Minimum 40 GB free disk space
- **Network**: Active internet connection
- **DNS** (production only): An A record pointing your domain to the server IP

## Quick Start

```bash
git clone https://github.com/Commquest-Technologies/erpnext-install.git
cd erpnext-install
chmod +x install.sh
./install.sh
```

Run this as **root** (typical on a fresh VPS from Vultr, DigitalOcean, Hetzner, etc.) — the script handles everything from there.

## Installation Flow

### Step 1: User Setup (When Running as Root)

```
root@server:~# ./install.sh

[WARN] Running as root. A non-root user is required for Frappe.

Enter username to create [frappe]: frappe
[INFO] Creating user 'frappe'...
[INFO] Set a login password for 'frappe':
New password: ********
Retype new password: ********
[OK] User frappe created with sudo access

[INFO] Re-launching installer as 'frappe'...
```

The password you set here is for **SSH/login access** (`ssh frappe@your-server`). The installer uses passwordless sudo internally.

If the user already exists, you will be prompted:

```
[WARN] User 'frappe' already exists.
Reuse existing user and continue? [Y/n]:
```

- **Y** (default) — Keeps existing user, bench, site, and database intact. Ideal for re-running after a failure.
- **n** — Deletes the user, home directory, and associated databases for a completely fresh start.

### Step 2: Configuration

| Prompt | Default | Description |
|--------|---------|-------------|
| Frappe version (15 or 16) | 16 | v15 = Python 3.10, v16 = Python 3.14 |
| System user | frappe | Linux user that owns the bench |
| Bench name | frappe-bench | Directory name under the user's home |
| Site name | *(required)* | e.g. `erp.mycompany.com` or `mysite.local` |
| Admin password | *(required)* | ERPNext Administrator login password |
| Domain | *(empty = dev mode)* | Enter a domain for production + SSL setup |
| Install ERPNext? | Y | Press N to install only the Frappe framework |

A summary is displayed before installation begins. You must confirm to proceed.

### Step 3: MariaDB Password

The script auto-detects your MariaDB state:

- **Fresh install** (socket authentication): You will be asked to create a new root password
- **Existing password**: You will be asked to enter it for verification

The password is verified without `sudo` to ensure bench can connect directly.

### Step 4: Automated Installation

The script then installs everything automatically:

1. System packages and build dependencies
2. Python, Node.js 24, Yarn, Redis, MariaDB, uv, pipx
3. MariaDB configuration (`utf8mb4`, `mysql_native_password`)
4. Frappe Bench CLI via pipx
5. Bench initialization and site creation
6. ERPNext download and installation (if selected)
7. **Production mode** (when domain is provided):
   - Nginx with correct file permissions for static assets
   - Supervisor for process management
   - SSL certificate via Let's Encrypt
8. **Development mode** (no domain): Starts `bench start` in the background
9. UFW firewall rules

## What Gets Installed

### System Packages

- Git, curl, wget, software-properties-common
- Build essentials and development libraries
- MariaDB Server and Client
- Redis Server
- Nginx (production mode)
- wkhtmltopdf and xvfb (PDF generation)
- python3-pip, python3-setuptools, python3-venv, pipx

### Languages and Tools

| Component | v15 | v16 |
|-----------|-----|-----|
| Python | 3.10 (deadsnakes PPA) | 3.14 (deadsnakes PPA) |
| Node.js | 24 (NodeSource) | 24 (NodeSource) |
| Yarn | Latest | Latest |
| uv | Latest | Latest |
| Bench CLI | Latest (via pipx) | Latest (via pipx) |

### Frappe Stack

- **Frappe Bench** — CLI tool for managing Frappe applications
- **Frappe Framework** — v15 (`version-15` branch) or v16 (`version-16` branch)
- **ERPNext** — v15 or v16 (optional)

### Production Services (When Domain Is Provided)

- **Nginx** — Web server and reverse proxy
- **Supervisor** — Process manager for Gunicorn, Redis, and background workers
- **Certbot** — SSL/TLS certificates via Let's Encrypt
- **UFW** — Firewall (ports 22, 80, 443, 8000)

## Project Structure

```
erpnext-install/
├── install.sh              # Main entry point
├── scripts/
│   ├── utils.sh            # Logging and helper functions
│   ├── preflight.sh        # OS checks, root-to-user handoff
│   ├── config.sh           # Interactive configuration prompts
│   ├── packages.sh         # System package installation
│   ├── mariadb.sh          # MariaDB password and configuration
│   ├── bench.sh            # Bench init, site creation, ERPNext download
│   ├── production.sh       # Production setup (Nginx, Supervisor, SSL)
│   ├── dev.sh              # Development mode startup
│   ├── firewall.sh         # UFW firewall rules
│   └── summary.sh          # Post-install summary
├── LICENSE
└── README.md
```

## Post-Installation

### Accessing ERPNext

1. Open your browser and navigate to:
   - **Production**: `https://yourdomain.com`
   - **Development**: `http://YOUR_SERVER_IP:8000`
2. Log in with:
   - **Username**: `Administrator`
   - **Password**: The admin password you set during installation

### DNS and SSL Setup

If SSL failed during installation (DNS not yet configured):

1. Create an **A record** at your DNS provider pointing your domain to the server IP
2. Wait for DNS propagation
3. Run:
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

## Useful Commands

```bash
# Switch to the frappe user
su - frappe

# Navigate to bench
cd ~/frappe-bench

# Development mode
bench start

# Production restart
sudo supervisorctl restart all

# Check service status
sudo supervisorctl status

# Rebuild frontend assets
bench build

# List installed apps
bench --site <site-name> list-apps

# Check versions
bench version

# Regenerate Nginx configuration
bench setup nginx
sudo systemctl restart nginx
```

## Troubleshooting

### Site Loads Without Styles (Unstyled HTML)

Nginx cannot read the bench assets. Fix file permissions:

```bash
sudo usermod -a -G frappe www-data
sudo chmod o+rx /home/frappe
sudo chmod -R o+rx /home/frappe/frappe-bench
bench build
sudo supervisorctl restart all
```

### Cannot Access the Site

```bash
sudo supervisorctl status
sudo systemctl status nginx
sudo ufw status
```

### Supervisor Issues

```bash
cd ~/frappe-bench
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart all
```

### Nginx Reload Fails (Invalid PID)

```bash
sudo systemctl restart nginx
```

### SSL Certificate Issues

Ensure your domain's DNS A record points to your server IP, then:

```bash
sudo certbot --nginx -d yourdomain.com
```

### MariaDB Connection Issues

```bash
sudo systemctl status mariadb
mysql -uroot -p -e "SELECT 1;"
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

**Commquest Technologies (Pty) Ltd**

- Phone: +27 72 720 4900
- Email: info@commquest.co.za
- GitHub: [Commquest-Technologies](https://github.com/Commquest-Technologies)

---

**Note**: This installer is designed for Ubuntu 22.04 and 24.04. Other distributions may require modifications.
