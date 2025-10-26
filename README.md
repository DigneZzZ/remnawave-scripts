# Remnawave Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/language-Bash-blue.svg)](#)
[![Version](https://img.shields.io/badge/version-3.5.5-blue.svg)](#)
[![Remnawave Panel](https://img.shields.io/badge/Installer-Remnawave-brightgreen)](#-remnawave-panel-installer)
[![RemnaNode](https://img.shields.io/badge/Installer-RemnaNode-lightgrey)](#-remnanode-installer)
[![Backup & Restore](https://img.shields.io/badge/Tool-Backup%20%26%20Restore-orange)](#-backup--restore-system)
[![Caddy Selfsteal](https://img.shields.io/badge/Tool-Caddy%20Selfsteal-purple)](#-caddy-selfsteal-for-reality)
[![Auto Updates](https://img.shields.io/badge/Feature-Auto%20Updates-green.svg)](#)
[![Telegram Integration](https://img.shields.io/badge/Feature-Telegram-blue.svg)](#)

![remnawave-script](remnawave-script.webp)

A comprehensive collection of enterprise-grade Bash scripts for **Remnawave Panel**, **RemnaNode**, and **Reality traffic masking** management. Featuring advanced backup/restore capabilities, automated scheduling, Telegram integration, and production-ready deployment tools.

## [Readme на русском](/README_RU.md)

## Support here: https://gig.ovh/t/remnawave-managment-scripts-by-dignezzz/116

---

## 🧭 Navigation Menu

<details>
<summary><b>📚 Table of Contents</b></summary>

### Core Installers
* [🚀 Remnawave Panel Installer](#-remnawave-panel-installer)
* [🛰 RemnaNode Installer](#-remnanode-installer)
* [🎭 Caddy Selfsteal for Reality](#-caddy-selfsteal-for-reality)

### Backup & Migration System
* [💾 Backup & Restore System](#-backup--restore-system)
* [📅 Scheduled Backups](#-scheduled-backups)
* [🔄 Migration & Restore](#%EF%B8%8F-migration--restore)
* [� Telegram Integration](#-telegram-integration)

### Advanced Features
* [🔐 Security Features](#-security-features)
* [🎛️ Management Commands](#%EF%B8%8F-management-commands)
* [📊 Monitoring & Logs](#-monitoring--logs)
* [⚙️ System Requirements](#%EF%B8%8F-system-requirements)

### Community & Support
* [🤝 Contributing](#-contributing)
* [📜 License](#-license)
* [👥 Community](#-community)

</details>


---

## 🚀 Remnawave Panel Installer

A comprehensive enterprise-grade Bash script to install and manage the [Remnawave Panel](https://github.com/remnawave/). Features full automation, advanced backup/restore capabilities, scheduled operations, and production-ready deployment tools.

### ✨ Key Features

**🎛️ Complete CLI Management**
* Full command interface: `install`, `up`, `down`, `restart`, `logs`, `status`, `edit`, `update`, `uninstall`
* Interactive main menu with colorized output
* Script self-updating with version checking
* Console access to internal panel CLI

**🔧 Advanced Installation**
* Auto-generation of `.env`, secrets, ports, and `docker-compose.yml`
* Development mode support with `--dev` flag
* Custom installation paths and names
* Automatic dependency detection and installation
* System requirements validation

**💾 Enterprise Backup & Restore System**
* **Full system backups** with compression (.tar.gz)
* **Database-only backups** (.sql, .sql.gz)
* **Scheduled backups** with cron integration
* **Complete migration system** between servers
* **Safety backups** with automatic rollback
* **Retention policies** with automatic cleanup

**📱 Telegram Integration**
* Bot notifications for operations and scheduled backups
* Large file support with chunked delivery
* Thread support for group chats
* Comprehensive status reporting

**🔄 Automatic Variable Migration (Remnawave v2.2.0+)**
* Auto-detection of deprecated environment variables
* Safe migration with automatic backup creation
* OAuth and Branding settings moved to UI
* Seamless upgrade experience with zero downtime

---

### 📦 Quick Start

```bash
# Install Remnawave Panel
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# Install only the management script
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-script --name remnawave
```

---

### ⚙️ Installation Options

| Flag | Description | Example |
|------|-------------|---------|
| `--name` | Custom installation directory name | `--name panel-prod` |
| `--dev` | Install development version | `--dev` |

**Examples:**
```bash
# Development installation with custom name
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name remnawave-dev --dev

# Production installation with custom name  
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name panel-prod
```

---

### 🛠 Management Commands

#### Core Operations
| Command | Description | Usage |
|---------|-------------|-------|
| `install` | Install Remnawave Panel | `remnawave install [--dev] [--name NAME]` |
| `update` | Update script and containers | `remnawave update` |
| `uninstall` | Remove panel completely | `remnawave uninstall` |
| `up` | Start all services | `remnawave up` |
| `down` | Stop all services | `remnawave down` |
| `restart` | Restart panel | `remnawave restart` |
| `status` | Show service status | `remnawave status` |

#### Configuration & Maintenance
| Command | Description | Usage |
|---------|-------------|-------|
| `edit` | Edit docker-compose.yml | `remnawave edit` |
| `edit-env` | Edit .env file | `remnawave edit-env` |
| `logs` | View container logs | `remnawave logs [--follow]` |
| `console` | Access panel CLI console | `remnawave console` |

#### Backup System
| Command | Description | Usage |
|---------|-------------|-------|
| `backup` | Create manual backup | `remnawave backup [--no-compress] [--data-only]` |
| `restore` | Restore from backup | `remnawave restore [--file FILE] [--database-only]` |
| `schedule` | Manage scheduled backups | `remnawave schedule` |

---

### 💾 Backup & Restore System

#### Manual Backups
```bash
# Full system backup (compressed by default)
remnawave backup

# Database only backup  
remnawave backup --data-only

# Uncompressed backup (not recommended)
remnawave backup --no-compress
```

#### Scheduled Backups
```bash
# Configure automated backups
remnawave schedule

# Available schedule options:
# - Daily, Weekly, Monthly intervals
# - Compression settings
# - Retention policies (days, minimum backups)
# - Telegram delivery configuration
# - Automatic backup script version checking
```

#### Migration & Restore
```bash
# Complete system migration
remnawave restore --file backup.tar.gz --name newpanel --path /opt

# Database only restore
remnawave restore --database-only --file database.sql.gz

# Restore with safety backup
remnawave restore --file backup.tar.gz  # Automatic safety backup created
```

**🔍 Version Compatibility:**
- Panel version included in all backup metadata and notifications
- Strict version checking: Major/minor versions must match for restore
- Patch version differences show warnings but allow restore
- Script version managed separately from panel version

**� Recommended Restore Method:**
```bash
# Transfer backup file to target server, then:
sudo remnawave restore --file backup.tar.gz

# For database-only backups:
sudo remnawave restore --database-only --file database.sql.gz
```

**🛠 Manual Restore (if automatic fails):**
```bash
# Option A: New installation (recommended)
curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh
sudo bash remnawave.sh @ install --name remnawave
sudo remnawave down
tar -xzf backup.tar.gz
cat backup_folder/database.sql | docker exec -i -e PGPASSWORD="actual_password" remnawave-db psql -U postgres -d postgres

# Option B: Existing installation  
sudo remnawave down
cat database.sql | docker exec -i -e PGPASSWORD="actual_password" remnawave-db psql -U postgres -d postgres
sudo remnawave up
```

⚠️ **Note:** Built-in `restore` function includes automatic version checking, safety backups, and error handling.

---

### 🔄 Automatic Variable Migration (Remnawave v2.2.0+)

**Starting with Remnawave v2.2.0**, many environment variables have been moved to the UI panel for better management and security.

**Deprecated Variables (Auto-migrated):**
```bash
# OAuth Settings → Now in Panel UI
TELEGRAM_OAUTH_ENABLED
TELEGRAM_OAUTH_ADMIN_IDS
OAUTH2_GITHUB_ENABLED
OAUTH2_GITHUB_CLIENT_ID
OAUTH2_GITHUB_CLIENT_SECRET
OAUTH2_GITHUB_ALLOWED_EMAILS
OAUTH2_POCKETID_ENABLED
OAUTH2_POCKETID_CLIENT_ID
OAUTH2_POCKETID_CLIENT_SECRET
OAUTH2_POCKETID_ALLOWED_EMAILS
OAUTH2_POCKETID_PLAIN_DOMAIN
OAUTH2_YANDEX_ENABLED
OAUTH2_YANDEX_CLIENT_ID
OAUTH2_YANDEX_CLIENT_SECRET
OAUTH2_YANDEX_ALLOWED_EMAILS

# Branding Settings → Now in Panel UI
BRANDING_LOGO_URL
BRANDING_TITLE
```

**Automatic Migration Process:**
```bash
# Migration happens automatically during update
remnawave update

# What happens:
# 1. Detects deprecated variables in .env
# 2. Creates backup: /opt/remnawave/.env.backup.TIMESTAMP
# 3. Removes deprecated variables from .env
# 4. Shows migration summary
# 5. Guides to configure settings in panel UI
```

**Configure in Panel UI:**
- **Settings → Authentication → Login Methods** (OAuth settings)
- **Settings → Branding** (Logo and title)

**Benefits:**
- ✅ No more panel restarts for configuration changes
- ✅ Real-time preview of branding changes
- ✅ Secure credential management in UI
- ✅ Cleaner .env file

---

### � Telegram Integration

Configure during installation or via `.env`:

```bash
# Enable Telegram notifications
IS_TELEGRAM_NOTIFICATIONS_ENABLED=true
TELEGRAM_BOT_TOKEN=your_bot_token

# User notifications
TELEGRAM_NOTIFY_USERS_CHAT_ID=your_chat_id
TELEGRAM_NOTIFY_USERS_THREAD_ID=thread_id  # Optional

# Node notifications  
TELEGRAM_NOTIFY_NODES_CHAT_ID=your_chat_id
TELEGRAM_NOTIFY_NODES_THREAD_ID=thread_id  # Optional
```

**Features:**
- Backup completion notifications
- System status alerts
- Large file delivery (>50MB) with chunked uploads
- Thread support for organized group chats

---

### 🌍 Production Deployment

**Reverse Proxy Setup**
```nginx
# Nginx example
server {
    server_name panel.example.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    server_name sub.example.com;
    location /sub {
        proxy_pass http://127.0.0.1:3010;
        proxy_set_header Host $host;
    }
}
```

**Environment Variables**
```bash
# Panel access domain
FRONT_END_DOMAIN=panel.example.com

# Subscription domain (without protocol)
SUB_PUBLIC_DOMAIN=sub.example.com

# Database performance
API_INSTANCES=2  # Number of API instances
```

---

### 📂 File Structure

```text
/opt/remnawave/                    # Default installation
├── .env                          # Main configuration
├── .env.subscription             # Subscription page config
├── docker-compose.yml            # Container orchestration
├── app-config.json              # Optional app configuration
├── backup-config.json           # Backup system config
├── backup-scheduler.sh          # Automated backup script
├── backups/                     # Backup storage
│   ├── remnawave_full_*.tar.gz  # Full system backups
│   ├── remnawave_db_*.sql.gz    # Database backups
│   └── remnawave_scheduled_*    # Automated backups
└── logs/                        # System logs
    ├── backup.log               # Backup operations log
    └── panel.log               # Panel operations log

/usr/local/bin/remnawave          # Management script
```

---

## 🛰 RemnaNode Installer

A production-ready Bash script to install and manage **RemnaNode** - high-performance proxy nodes with advanced Xray-core integration. Designed for seamless connection to Remnawave Panel with enterprise-grade features.

### ✨ Key Features

**🎛️ Complete Node Management**
* Full CLI interface: `install`, `up`, `down`, `restart`, `status`, `logs`, `update`, `uninstall`
* Interactive main menu with adaptive terminal sizing
* Automatic port conflict detection and resolution
* Real-time log monitoring for Xray-core

**⚡ Advanced Xray-core Integration**
* Automatic latest version detection and installation
* Interactive version selection with pre-release support
* Custom Xray-core binary management
* Real-time log streaming (`xray_log_out`, `xray_log_err`)

**🔧 Production Features**
* Log rotation with configurable retention
* Multi-architecture support (x86_64, ARM64, ARM32, MIPS)
* Development mode support with `--dev` flag
* Comprehensive system requirements validation
* **Universal configuration support**: `.env` files and inline docker-compose variables
* **Automatic environment variable migration** with backup support

---

### 📦 Quick Start

```bash
# Install RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Install with custom name
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install --name node-prod

# Install development version
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install --dev --name node-dev
```

---

### 🛠 Management Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `install` | Install RemnaNode | `remnanode install [--dev] [--name NAME]` |
| `update` | Update script and container | `remnanode update` |
| `uninstall` | Remove node and data | `remnanode uninstall` |
| `up` | Start node services | `remnanode up` |
| `down` | Stop node services | `remnanode down` |
| `restart` | Restart node | `remnanode restart` |
| `status` | Show service status | `remnanode status` |
| `logs` | View container logs | `remnanode logs` |
| `core-update` | Update Xray-core binary | `remnanode core-update` |
| `edit` | Edit docker-compose.yml | `remnanode edit` |
| `edit-env` | Edit .env file | `remnanode edit-env` |
| `setup-logs` | Configure log rotation | `remnanode setup-logs` |
| `xray_log_out` | Monitor Xray output logs | `remnanode xray_log_out` |
| `xray_log_err` | Monitor Xray error logs | `remnanode xray_log_err` |

---

### ⚡ Xray-core Management

**Automatic Installation**
```bash
# Install latest Xray-core during setup
remnanode install  # Automatically offers latest Xray-core

# Update to specific version
remnanode core-update  # Interactive version selection
```

**Real-time Monitoring**
```bash
# Monitor Xray output in real-time
remnanode xray_log_out

# Monitor Xray errors
remnanode xray_log_err

# Standard container logs
remnanode logs
```

---

### 🔧 Production Configuration

**Environment Variable Migration**

Starting with **RemnaNode v2.2.2+**, environment variables have been renamed for better clarity:
- `APP_PORT` → `NODE_PORT` 
- `SSL_CERT` → `SECRET_KEY`

**Universal Configuration Support:**

The script now supports **both** `.env` files and inline environment variables in `docker-compose.yml`:

```bash
# Option 1: Using .env file (Recommended)
# /opt/remnanode/.env
NODE_PORT=3000
SECRET_KEY=your_secret_key

# Option 2: Inline in docker-compose.yml (Also supported)
# docker-compose.yml
services:
  remnanode:
    environment:
      - NODE_PORT=3000
      - SECRET_KEY=your_secret_key
```

**Automatic Migration Process:**
```bash
# Migration happens automatically during update
remnanode update

# What happens during migration:
# 1. Auto-detects configuration type (.env or inline)
# 2. Creates backup with timestamp
# 3. Migrates old variables:
#    - APP_PORT → NODE_PORT
#    - SSL_CERT → SECRET_KEY
# 4. For inline variables: Offers migration to .env (more secure)
# 5. Applies changes with automatic restart
```

**New Smart Edit Command:**
```bash
# Automatically detects configuration and opens appropriate editor
remnanode edit-env

# Behavior:
# - .env exists → Opens .env file
# - Inline variables → Offers migration to .env
# - No config → Creates new .env template
```

**Backward Compatibility:**
* ✅ Old variables (`APP_PORT`, `SSL_CERT`) work via fallback
* ✅ Both .env and inline configurations supported
* ✅ Seamless migration with zero downtime
* ✅ No manual intervention required

**Log Rotation Setup**
```bash
# Configure automatic log rotation
remnanode setup-logs

# Rotation settings:
# - Max size: 50MB per log file
# - Keep 5 rotated files
# - Compress old logs
# - Safe truncation without stopping services
```

**Security Hardening**
```bash
# Recommended UFW configuration
sudo ufw allow from PANEL_IP to any port NODE_PORT
sudo ufw enable

# The script automatically:
# - Detects occupied ports
# - Suggests available alternatives
# - Validates port ranges
```

---

### 📂 File Structure

```text
/opt/remnanode/                   # Node installation
├── .env                         # Environment configuration
└── docker-compose.yml          # Container orchestration

/var/lib/remnanode/              # Data directory
├── xray                        # Xray-core binary (if installed)
├── access.log                  # Xray access logs
├── error.log                   # Xray error logs
└── *.log                       # Additional Xray logs

/usr/local/bin/remnanode         # Management script
/etc/logrotate.d/remnanode       # Log rotation config
```

---

### 🌐 Multi-Architecture Support

**Supported Platforms:**
- **x86_64** (Intel/AMD 64-bit)
- **ARM64** (ARMv8 64-bit) 
- **ARM32** (ARMv7 32-bit)
- **MIPS** (MIPS architecture)

**Automatic Detection:**
The script automatically detects your system architecture and downloads the appropriate Xray-core binary.

---

## 🎭 Caddy Selfsteal for Reality

A specialized Bash script for deploying **Caddy as a Reality traffic masking solution**. Provides legitimate HTTPS traffic camouflage for Xray Reality configurations with professional web templates.

### ✨ Key Features

**🎭 Traffic Masking**
* Professional website templates for traffic camouflage
* Automatic HTTPS certificate management
* Configurable ports for Reality integration
* DNS validation with propagation checking

**🌐 Template System**
* Multiple pre-built website templates
* Automatic template downloading and installation
* Fallback HTML creation if download fails
* Professional appearance for traffic masking

**🔧 Reality Integration**
* Port configuration for Xray Reality compatibility
* Automatic redirects and traffic handling
* Internal certificate management
* DNS validation for proper setup

---

### � Quick Start

```bash
# Install Caddy Selfsteal
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

---

### 🛠 Management Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `install` | Install Caddy Selfsteal | `selfsteal install` |
| `up` | Start Caddy services | `selfsteal up` |
| `down` | Stop Caddy services | `selfsteal down` |
| `restart` | Restart Caddy | `selfsteal restart` |
| `status` | Show service status | `selfsteal status` |
| `logs` | View Caddy logs | `selfsteal logs` |
| `template` | Manage website templates | `selfsteal template` |
| `edit` | Edit Caddyfile | `selfsteal edit` |
| `uninstall` | Remove Caddy setup | `selfsteal uninstall` |
| `guide` | Show Reality integration guide | `selfsteal guide` |
| `update` | Update script | `selfsteal update` |

---

### 🎨 Template Management

**Available Templates:**
- **10gag** - Social media style template
- **converter** - File converter service template  
- **downloader** - Download service template
- **filecloud** - Cloud storage template
- **games-site** - Gaming website template
- **modmanager** - Mod management template
- **speedtest** - Speed test service template
- **YouTube** - Video platform template

**Template Operations:**
```bash
# List available templates
selfsteal template list

# Install specific template
selfsteal template install converter

# Show current template info
selfsteal template info

# Download template manually
selfsteal template download speedtest
```

---

### 🔗 Reality Integration

**Configuration for Xray Reality:**
```json
{
  "realitySettings": {
    "dest": "127.0.0.1:9443",
    "serverNames": ["your-domain.com"]
  }
}
```

**Caddy Configuration:**
```caddyfile
# Automatic generation during setup
{
    https_port 9443
    default_bind 127.0.0.1
    auto_https disable_redirects
}

https://your-domain.com {
    root * /var/www/html
    file_server
}
```

---

### 🔐 DNS Validation

**Automatic Checks:**
- Domain format validation
- A record DNS resolution
- AAAA record (IPv6) checking
- CNAME record detection
- DNS propagation across multiple servers (8.8.8.8, 1.1.1.1, etc.)
- Port availability verification

**Setup Requirements:**
- Domain must point to server IP
- Port 443 free for Xray Reality
- Port 80 available for HTTP redirects
- Proper DNS propagation

---

### 📂 File Structure

```text
/opt/caddy/                      # Caddy installation
├── .env                        # Environment configuration
├── docker-compose.yml         # Container orchestration
├── Caddyfile                   # Caddy configuration
├── logs/                       # Caddy logs
└── html/                       # Website content
    ├── index.html             # Main page
    ├── 404.html               # Error page
    └── assets/                # Template assets
        ├── style.css          # Styling
        ├── script.js          # JavaScript
        └── images/            # Images and icons

/usr/local/bin/selfsteal        # Management script
```

## ⚙️ System Requirements

### 🖥️ Supported Operating Systems

**Linux Distributions:**
* **Ubuntu** 18.04+ (LTS recommended)
* **Debian** 10+ (Buster and newer)
* **CentOS** 7+ / **AlmaLinux** 8+
* **Amazon Linux** 2
* **Fedora** 32+
* **Arch Linux** (rolling)
* **openSUSE** Leap 15+

### 🏗️ Hardware Requirements

**Minimum Requirements:**
* **CPU**: 1 core (2+ cores recommended for production)
* **RAM**: 512MB (1GB+ recommended)
* **Storage**: 2GB free space (5GB+ for backups)
* **Network**: Stable internet connection

**Recommended for Production:**
* **CPU**: 2+ cores
* **RAM**: 2GB+
* **Storage**: 10GB+ SSD storage
* **Network**: 100Mbps+ connection

### 🏛️ Architecture Support

**Supported Architectures:**
* **x86_64** (Intel/AMD 64-bit) - Primary support
* **ARM64** (ARMv8 64-bit) - Full support
* **ARM32** (ARMv7 32-bit) - Basic support
* **MIPS** - Limited support

### � Dependencies

**Automatically Installed:**
* Docker Engine (latest stable)
* Docker Compose V2
* curl / wget
* openssl
* jq (for JSON processing)
* unzip / tar / gzip

**Text Editors (Auto-detected):**
* nano (default)
* vim / vi
* micro
* emacs

---

## 🔐 Security Features

### 🛡️ Built-in Security

**Network Security:**
* All services bind to `127.0.0.1` by default
* Automatic port conflict detection
* UFW firewall configuration guidance
* SSL/TLS certificate management

**Data Protection:**
* Database credentials auto-generation
* JWT secrets randomization
* Environment variable validation
* Secure backup encryption support

**Access Control:**
* Telegram OAuth integration
* Admin ID validation
* Rate limiting support
* Webhook signature verification

### 🔒 Production Hardening

**Recommended Security Setup:**
```bash
# Configure UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from trusted_ip to any port panel_port
sudo ufw enable

# Regular security updates
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
sudo yum update -y  # CentOS/AlmaLinux

# Monitor logs
remnawave logs --follow
tail -f /var/log/auth.log
```

**Environment Security:**
* Regular backup verification
* Database access auditing
* Container image scanning
* Dependency vulnerability monitoring

---

## 📊 Monitoring & Logs

### 📈 System Monitoring

**Built-in Monitoring:**
```bash
# Service status
remnawave status
remnanode status
selfsteal status

# Resource usage
docker stats
docker system df

# Log monitoring
remnawave logs --follow
remnanode logs
selfsteal logs
```

**Metrics Integration:**
* Prometheus metrics endpoint (`/api/metrics`)
* Custom metrics collection
* Performance monitoring
* Resource usage tracking

### 📋 Log Management

**Log Locations:**
```text
# Panel logs
/opt/remnawave/logs/
├── backup.log              # Backup operations
├── panel.log               # Panel operations  
└── docker-compose.log      # Container logs

# Node logs
/var/lib/remnanode/
├── access.log              # Xray access logs
├── error.log               # Xray error logs
└── node.log                # Node operations

# Caddy logs
/opt/caddy/logs/
├── access.log              # HTTP access
├── error.log               # HTTP errors
└── caddy.log               # Caddy operations
```

**Log Rotation:**
* Automatic rotation (50MB max per file)
* Compression of old logs
* Configurable retention (5 files default)
* Safe truncation without service interruption

---

## 🤝 Contributing

We welcome contributions to improve the Remnawave Scripts! Here's how you can help:

### 🐛 Bug Reports

1. **Check existing issues** before creating new ones
2. **Provide detailed information:**
   * OS and version
   * Script version
   * Error messages
   * Steps to reproduce

### 💡 Feature Requests

1. **Describe the use case** clearly
2. **Explain the expected behavior**
3. **Consider backward compatibility**
4. **Provide implementation ideas** if possible

### 🔧 Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Update documentation**
6. **Submit pull request**

**Development Guidelines:**
* Follow existing code style
* Add comments for complex logic
* Test on multiple distributions
* Update README if needed

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](./LICENSE) file for details.

### 🔓 MIT License Summary

* ✅ **Commercial use** allowed
* ✅ **Modification** allowed  
* ✅ **Distribution** allowed
* ✅ **Private use** allowed
* ❌ **No liability** for authors
* ❌ **No warranty** provided

---

## 👥 Community

### 🌐 Join Our Communities

**🔗 GIG.ovh**  
* **Website**: [https://gig.ovh](https://gig.ovh)
* **FOCUS**: Next-Gen forum comminity with AI ChatBot, VIP Groups and other..

**🔗 OpeNode.XYZ**
* **Website**: [https://openode.xyz](https://openode.xyz)
* **Focus**: Open-source networking solutions
* **Community**: Developers and system administrators
* **Topics**: Proxy panels, VPN solutions, networking tools

**🔗 NeoNode.cc**  
* **Website**: [https://neonode.cc](https://neonode.cc)


---

<div align="center">

**⭐ If you find this project helpful, please consider giving it a star!**

**🔗 [Report Bug](https://github.com/DigneZzZ/remnawave-scripts/issues) • [Request Feature](https://github.com/DigneZzZ/remnawave-scripts/issues) • [Contribute](https://github.com/DigneZzZ/remnawave-scripts/pulls)**

</div>
