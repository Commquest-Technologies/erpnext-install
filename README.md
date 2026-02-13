# Frappe/ERPNext Automated Installer (v15 & v16)

A modular bash script to install **Frappe Framework** and **ERPNext** on Ubuntu systems. Supports **Frappe v15** and **v16** — you choose the version at the start.

## Features

- **Frappe v15 or v16** — choose version at install time (Python 3.10 for v15, Python 3.14 for v16)
- Automated installation of all dependencies (Node.js, Yarn, Redis, MariaDB, uv, pipx)
- Node.js 24 for both versions with latest bench
- MariaDB setup with interactive or existing password support
- Bench initialization with optional ERPNext app installation
- Production-ready setup with Nginx and Supervisor
- Optional SSL certificate setup with Let's Encrypt
- UFW firewall configuration
- Confirmation prompt before starting installation

## Prerequisites

- **Operating System**: Ubuntu 22.04 / 24.04 (fresh installation recommended)
- **User Access**: A regular user with sudo privileges (do NOT run as root)
- **RAM**: Minimum 4GB (8GB recommended for production)
- **Storage**: Minimum 40GB free disk space
- **Network**: Active internet connection

## Quick Start

### Step 1: Download the Script

```bash
git clone https://github.com/Commquest-Technologies/erpnext-install.git
cd erpnext-install
```

### Step 2: Make it Executable

```bash
chmod +x frappe_installer.sh
```

### Step 3: Run the Installer

```bash
./frappe_installer.sh
```

## Installation Process

When you run the script, you'll be prompted for the following information:

### 1. Frappe Version (15 or 16)
```
Enter Frappe version (15 or 16): 16
```
- **15** — Frappe/ERPNext v15 (Python 3.10, Node.js 24)
- **16** — Frappe/ERPNext v16 (Python 3.14, Node.js 24)

### 2. System User
```
Enter system user for Frappe [frappe]:
```
- Linux user that will own the Frappe/ERPNext application
- Defaults to `frappe` if left empty
- The script will create this user if it doesn't exist

### 3. Bench Name
```
Enter bench name [frappe-bench]:
```
- Name of the bench directory
- Created at: `/home/<user>/<bench-name>`

### 4. Site Name
```
Enter site name: mysite.local
```
- For local/development: use `.local` domain (e.g., `mysite.local`)
- For production: use your actual domain (e.g., `erp.mycompany.com`)

### 5. Admin Password
```
Enter admin password:
```
- Password for the Administrator account
- Choose a strong password

### 6. Domain (Optional)
```
Enter domain (leave empty for dev mode):
```
- Enter your domain for production mode with SSL
- Leave empty for development mode
- Domain must be pointing to your server's IP address

### 7. ERPNext Installation
```
Install ERPNext app? [Y/n]:
```
- Choose whether to install ERPNext on the site
- If you say no, only the Frappe framework is installed

### 8. MariaDB Setup

The script will ask:
```
Do you have a MariaDB root password? (y/n):
```

**Option A: You already have a password (y)** — Enter it and the script will verify it.

**Option B: Fresh install (n)** — The script will let you set a new password or use socket authentication.

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
├── frappe_installer.sh      # Main entry point
├── scripts/
│   ├── common.sh            # Logging and helper functions
│   ├── system_checks.sh     # OS and RAM checks
│   ├── user_input.sh        # Interactive prompts
│   ├── system_packages.sh   # Package installation (Python, Node, uv, etc.)
│   ├── mariadb_config.sh    # MariaDB password and config
│   ├── bench_setup.sh       # Bench init, site creation, ERPNext download
│   ├── mode_production.sh   # Production setup (nginx, supervisor, SSL)
│   ├── mode_dev.sh          # Development mode startup
│   ├── firewall.sh          # UFW configuration
│   └── summary.sh           # Post-install summary
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
