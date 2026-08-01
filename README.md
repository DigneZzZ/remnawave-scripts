<div align="center">

<img src="assets/hero.svg" alt="Remnawave Scripts" width="880">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/language-Bash-blue.svg)](#)
[![Version](https://img.shields.io/badge/remnawave.sh-6.4.0-blue.svg)](#)
[![Panel v3](https://img.shields.io/badge/Remnawave_Panel-v3_ready-brightgreen.svg)](#)
[![Localization](https://img.shields.io/badge/🌐-EN_|_RU-green.svg)](./README_RU.md)

**[Русский](./README_RU.md)** · **[Quick Start](#-quick-start)** · **[Scripts](#-scripts)** · **[Backups](#-backups--migration)** · **[Support](https://gig.ovh/t/remnawave-managment-scripts-by-dignezzz/116)**

</div>

One-liner installs and a full-featured CLI for **Remnawave Panel**, **RemnaNode**, **Reality masking**, **WARP/Tor**, and enterprise-grade backups. Docker-based, bilingual UI (EN/RU), idempotent operations, self-updates.

> 🆕 **Remnawave Panel v3.0.0 supported out of the box.** Fresh installs get v3 config right away, and `remnawave update` migrates your `.env` from v2 automatically — with target image version checking and a backup of every file it touches.

## ⚡ Quick Start

```bash
# Remnawave Panel
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Caddy Selfsteal — Reality masking
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

After installation each script is a global command: `remnawave`, `remnanode`, `selfsteal` — run without arguments to open the interactive menu.

## 📦 Scripts

| Script | Purpose | Docs |
|---|---|---|
| 🚀 **remnawave.sh** | Panel: install, Caddy, backups, subscription-page | this file |
| 🛰 **remnanode.sh** | Node: Xray-core, logs, auto-restart | this file |
| 🎭 **selfsteal.sh** | Caddy masking for Reality, 8 website templates | [README-selfsteal](./README-selfsteal.md) |
| 🌐 **wtm.sh** | WARP + Tor: WireGuard outbound for Xray, WARP+ | [README-warp](./README-warp.md) |
| 🐦 **netbird.sh** | NetBird mesh VPN: CLI / cloud-init / Ansible | [README-netbird](./README-netbird.md) |

---

## 🚀 Remnawave Panel

<div align="center"><img src="assets/preview-remnawave.svg" alt="remnawave menu" width="720"></div>

- **Turnkey install** — `.env`, secrets, ports, compose, and the admin account are generated automatically (credentials in `admin-credentials.txt`)
- **Caddy reverse proxy** — auto-SSL, optional authentication portal with MFA (Caddy Security)
- **Subscription-page** — alongside the panel or standalone on a separate server; API token created automatically with least-privilege scopes
- **Safe `update`** — DB + config snapshot before every update, plus automatic migrations (including v2 → v3)
- **Telegram** — notifications and backup delivery, thread and proxy support

```bash
remnawave              # interactive menu
remnawave update       # update script, images, run migrations
remnawave backup       # manual backup (or `schedule` for cron)
```

<details>
<summary><b>📋 CLI commands & install flags</b></summary>

| Command | Description |
|---|---|
| `install` / `uninstall` | Install / remove completely |
| `install --name X --dev` | Custom directory name, dev image |
| `up` / `down` / `restart` / `status` / `logs` | Service lifecycle |
| `update` | Update script and containers with migrations |
| `backup` / `restore` / `schedule` | Backups: manual, restore, cron |
| `edit` / `edit-env` / `console` | compose, .env, panel console |
| `subpage` / `subpage-token` / `subpage-restart` | Subscription-page management |
| `install-subpage-standalone --with-caddy` | Subpage on a separate server |
| `caddy …` | Caddy install & management (`up/down/logs/edit/reset-user`) |

</details>

<details>
<summary><b>📂 File structure</b></summary>

```text
/opt/remnawave/            # .env, docker-compose.yml, backups/, logs/
/opt/caddy-remnawave/      # Caddy (if installed)
/usr/local/bin/remnawave   # CLI command
```

</details>

---

## 🛰 RemnaNode

<div align="center"><img src="assets/preview-remnanode.svg" alt="remnanode menu" width="720"></div>

- **Xray-core** — install and update from the menu, pre-releases included; real-time Xray logs
- **Non-interactive mode** — `--force --secret-key="KEY"` for mass provisioning
- **NET_ADMIN** capability and config migrations applied automatically on `update`
- **Log rotation** — 50 MB × 5 files, zero downtime; multi-arch: x86_64 / ARM64 / ARM32 / MIPS

```bash
remnanode                 # interactive menu
remnanode core-update     # update Xray-core
remnanode xray_log_err    # real-time Xray errors
```

<details>
<summary><b>📋 CLI commands & install flags</b></summary>

| Install flag | Description |
|---|---|
| `--force`, `-f` | Skip confirmations (for automation) |
| `--secret-key=KEY` | SECRET_KEY from the Panel (required with `--force`) |
| `--port=PORT` / `--xtls-port=PORT` | NODE_PORT (3000) / XTLS_API_PORT (61000) |
| `--xray` / `--no-xray` | Whether to install Xray-core |
| `--name NAME` / `--dev` | Directory name / dev image |

| Command | Description |
|---|---|
| `install` / `uninstall` / `update` | Lifecycle |
| `up` / `down` / `restart` / `status` / `logs` | Service management |
| `core-update` | Xray-core update |
| `xray_log_out` / `xray_log_err` | Real-time Xray logs |
| `setup-logs` / `auto-restart` | Log rotation / scheduled auto-restart |

```text
/opt/remnanode/            # .env, docker-compose.yml
/var/lib/remnanode/        # Xray binary
/usr/local/bin/remnanode   # CLI command
```

</details>

---

## 🎭 Caddy Selfsteal

<div align="center"><img src="assets/preview-selfsteal.svg" alt="selfsteal menu" width="720"></div>

- **8 website templates** for camouflage: social, converters, file clouds, speedtest, and more
- **Anti-fingerprint** — every template is uniquified on install (no byte-identical copies), provenance traces stripped
- **Built-in guide** for Reality integration (`selfsteal guide`)

```bash
selfsteal template list                 # list templates
selfsteal template install converter    # install a template
```

```jsonc
// Xray Reality: dest points to Caddy
{ "realitySettings": { "dest": "127.0.0.1:9443", "serverNames": ["your-domain.com"] } }
```

Details (HTTP/3, `--no-randomize`, structure): **[README-selfsteal.md](./README-selfsteal.md)**

---

## 🌐 WTM — WARP & Tor Manager

<div align="center"><img src="assets/preview-wtm.svg" alt="wtm menu" width="720"></div>

- **WARP** as a native WireGuard outbound for Xray (no TUN interface) + **WARP+** support
- **Tor** SOCKS5 proxy and `.onion` routing through Xray
- Connection tests, watchdog, ready-to-paste Xray config snippets

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script
sudo wtm    # menu; or: wtm install-all / warp-plus / status
```

Full documentation: **[README-warp.md](./README-warp.md)**

## 🐦 NetBird

Installer for [NetBird](https://netbird.io/) mesh VPN: CLI, cloud-init, interactive menu, Ansible mode.

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key YOUR-SETUP-KEY
```

Full documentation: **[README-netbird.md](./README-netbird.md)**

---

## 💾 Backups & Migration

```bash
remnawave backup                     # full backup (.tar.gz) or --data-only (DB only)
remnawave schedule                   # cron schedule, retention, Telegram delivery
remnawave restore --file backup.tar.gz
```

Before every `update` a safety snapshot (DB dump + configs) is created under `backups/pre-update-*`. Restores are checked for panel version compatibility.

<details>
<summary><b>🚚 Server migration & manual restore</b></summary>

```bash
# 1. On the old server
remnawave backup
# 2. Transfer the archive (scp) to the new server
# 3. On the new server
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name remnawave
remnawave restore --file backup.tar.gz
```

If automation fails — manual DB restore:

```bash
sudo remnawave down
cat database.sql | docker exec -i -e PGPASSWORD="password" remnawave-db psql -U postgres -d postgres
sudo remnawave up
```

> ⚠️ When restoring a DB onto a **fresh** install, copy the secret from the old `.env`: `APP_SECRET` (panel v3+) or `JWT_AUTH_SECRET`+`JWT_API_TOKENS_SECRET` (v2) — otherwise you'll get a 403 on login.

</details>

---

## ⚙️ Requirements & Security

**OS:** Ubuntu 18.04+ / Debian 10+ / CentOS 7+ / AlmaLinux 8+ / Fedora 32+ / Arch / openSUSE 15+ · **Minimum:** 1 CPU, 512 MB RAM · **Recommended:** 2+ CPU, 2 GB RAM, SSD
**Dependencies** (auto-installed): Docker + Compose v2, curl, openssl, jq

- All services bind to `127.0.0.1` only; public access goes through Caddy with auto-SSL
- Secrets, DB credentials, and API tokens are generated automatically
- Diagnostics: `remnawave status` / `logs --follow` / the "Health check" menu item

<details>
<summary><b>🔒 Production hardening (UFW)</b></summary>

```bash
sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw allow ssh && sudo ufw allow 443/tcp
sudo ufw enable
```

</details>

---

<div align="center">

**⭐ Star this project if you find it useful!**

[Report Bug](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Request Feature](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Community gig.ovh](https://gig.ovh) · [MIT License](./LICENSE)

*PRs welcome: fork → branch → changes → PR. Please test on multiple distros.*

</div>
