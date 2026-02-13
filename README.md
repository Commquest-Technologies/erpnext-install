# Frappe/ERPNext Automated Installer (v15 & v16)

A modular bash script to install **Frappe Framework** and **ERPNext** on Ubuntu systems. Supports **Frappe v15** and **v16** — you choose the version at the start.

## Features

- **Frappe v15 or v16** — choose version at install time (Python 3.10 for v15, Python 3.14 for v16)
- Automated installation of all dependencies (Node.js 24, Yarn, Redis, MariaDB, uv, pipx)
- Automatic non-root user creation when run as root (ideal for fresh VPS)
- If the user already exists, it is deleted and recreated for a clean setup
- MariaDB setup with interactive or existing password support
- Bench initialization with optional ERPNext app installation
- Production-ready setup with Nginx and Supervisor
- Optional SSL certificate setup with Let's Encrypt
- UFW firewall configuration
- Confirmation prompt before starting installation

## Prerequisites

- **Operating System**: Ubuntu 22.04 / 24.04 (fresh installation recommended)
- **RAM**: Minimum 4GB (8GB recommended for production)
- **Storage**: Minimum 40GB free disk space
- **Network**: Active internet connection

## Quick Start

```bash
git clone https://github.com/Commquest-Technologies/erpnext-install.git
cd erpnext-install
chmod +x install.sh
./install.sh
```

You can run this as **root** (typical on a fresh VPS like Vultr, DigitalOcean, etc.) — the script will automatically create a non-root user, set a password, and re-launch itself as that user.

## Installation Flow

### Running as Root (fresh VPS)

```
root@server:~# ./install.sh

[WARN] Running as root. A non-root user is required for Frappe.

Enter username to create [frappe]: frappe
[INFO] Creating user 'frappe'...
[INFO] Set a login password for 'frappe':
New password: ********
Retype new password: ********
[✓] User frappe created with sudo access

[INFO] Re-launching installer as 'frappe'...

── installer continues automatically as frappe ──
```

The password you set here is for **SSH/login access** to the frappe user (`ssh frappe@your-server`). The installer itself uses passwordless sudo internally.

### Configuration Prompts

| Prompt | Description |
|--------|-------------|
| Frappe version (15 or 16) | v15 = Python 3.10, v16 = Python 3.14 |
| System user [frappe] | Linux user that owns the bench |
| Bench name [frappe-bench] | Directory name for the bench |
| Site name | e.g. `mysite.local` or `erp.mycompany.com` |
| Admin password | ERPNext Administrator login password |
| Domain | Leave empty for dev mode, or enter domain for production + SSL |
| Install ERPNext? [Y/n] | Skip to install only the Frappe framework |
| MariaDB password | Existing password or set a new one |

## What Gets Installed

### System Packages
- Git, curl, wget
- Build essentials and development libraries
- MariaDB Server & Client
- Redis Server
- wkhtmltopdf (for PDF generation)
- python3-pip, python3-setuptools, pipx

### Programming Languages & Tools

| Component | v15                | v16                |
|-----------|--------------------|--------------------|
| Python    | 3.10 (deadsnakes)  | 3.14 (deadsnakes)  |
| Node.js   | 24 (NodeSource)    | 24 (NodeSource)    |
| Yarn      | latest             | latest             |
| uv        | latest             | latest             |
| Bench     | pipx (latest)      | pipx (latest)      |

### Frappe Stack
- **Frappe Bench** (CLI tool for managing Frappe applications)
- **Frappe Framework v15 or v16**
- **ERPNext v15 or v16** (optional)

### Production Services (when domain is provided)
- **Nginx** (web server and reverse proxy)
- **Supervisor** (process manager for background workers)
- **Certbot** (SSL/TLS certificates via Let's Encrypt)
- **UFW Firewall** (ports 22, 80, 443, 8000)

## Project Structure

```
erpnext-install/
├── install.sh    # Main entry point
├── scripts/
│   ├── utils.sh           # Logging and helper functions
│   ├── preflight.sh       # OS checks, root-to-user handoff
│   ├── config.sh          # Interactive configuration prompts
│   ├── packages.sh        # System package installation
│   ├── mariadb.sh         # MariaDB password and config
│   ├── bench.sh           # Bench init, site creation, ERPNext download
│   ├── production.sh      # Production setup (nginx, supervisor, SSL)
│   ├── dev.sh             # Development mode startup
│   ├── firewall.sh        # UFW firewall rules
│   └── summary.sh         # Post-install summary
├── LICENSE
└── README.md
```

## Post-Installation

### Accessing ERPNext

1. Open your web browser
2. Navigate to:
   - **Development**: `http://YOUR_SERVER_IP:8000`
   - **Production**: `https://yourdomain.com`
3. Login with:
   - **Username**: `Administrator`
   - **Password**: The admin password you set during installation

## Useful Commands

```bash
# Navigate to bench
cd /home/<user>/frappe-bench

# Development mode
bench start

# Production restart
bench restart

# Check services
sudo supervisorctl status

# List installed apps
bench --site <site-name> list-apps

# Check versions
bench version
```

## Troubleshooting

### Can't Access the Site

```bash
sudo supervisorctl status
sudo systemctl status nginx
sudo ufw status
```

### Supervisor Issues

```bash
cd /home/<user>/frappe-bench
sudo bench setup production <user>
```

### SSL Certificate Issues

```bash
sudo certbot --nginx -d yourdomain.com
```

Ensure your domain's DNS A record points to your server's IP.

### MariaDB Connection Issues

```bash
sudo systemctl status mariadb
sudo mysql -uroot -p
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

**Note**: This script is designed for Ubuntu 22.04 and 24.04. Other distributions may require modifications.
