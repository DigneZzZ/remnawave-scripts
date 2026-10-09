<div align="center">

<img src="assets/hero.svg" alt="Remnawave Scripts" width="880">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/language-Bash-blue.svg)](#)
[![remnawave.sh](https://img.shields.io/badge/remnawave.sh-6.7.2-blue.svg)](#-remnawave-panel)
[![remnanode.sh](https://img.shields.io/badge/remnanode.sh-4.6.0-blue.svg)](#-remnanode)
[![Panel](https://img.shields.io/badge/Remnawave_Panel-3.4.x_ready-brightgreen.svg)](#)
[![Localization](https://img.shields.io/badge/🌐-EN_|_RU-green.svg)](./README_RU.md)

**[Русский](./README_RU.md)** · **[Quick Start](#-quick-start)** · **[Scripts](#-scripts)** · **[Backups](#-backups--migration)** · **[Support](https://gig.ovh/t/remnawave-managment-scripts-by-dignezzz/116)**

</div>

One-liner installs and a full-featured CLI for **Remnawave Panel**, **RemnaNode**, **Reality masking**, **WARP/Tor**, and enterprise-grade backups. Docker-based, bilingual UI (EN/RU), idempotent operations, self-updates.

> 🆕 **Remnawave Panel 3.4.x and node 3.4.x supported out of the box.** Fresh installs get the
> current config right away — including the new `SHORT_UUID_METHOD` picker for subscription links
> (`nanoid` / `uuid` / custom pattern) — and `remnawave update` migrates an older `.env`
> automatically, with target image version checking and a backup of every file it touches.
>
> ⚠️ **Only the node line 3.3.0 … 3.3.2 requires panel 3.3.0+** (those releases enforce a
> derived-SNI TLS handshake). Node 3.4.0 made that check opt-in (`SNI_VERIFICATION`, off by
> default), so the latest node works with an older panel again.

## ⚡ Quick Start

```bash
# Remnawave Panel
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Caddy Selfsteal — Reality masking
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

Want only the CLI, without installing anything else? Swap `install` for **`install-script`** — it
just drops the command into `/usr/local/bin` (handy on a server you manage remotely, or to grab the
newest CLI right now):

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-script
```

> **GitHub blocked on your server?** Every script mirrors itself through jsDelivr, so use any of these
> instead of `github.com/.../raw/main/`:
> `https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/<script>.sh`
> Once installed, the scripts fall back to those mirrors on their own — including for self-updates.

After installation each script is a global command: `remnawave`, `remnanode`, `selfsteal` — run without arguments to open the interactive menu.

## 📦 Scripts

| Script | Version | Purpose | Docs |
|---|---|---|---|
| 🚀 **remnawave.sh** | `6.7.2` | Panel: install, Caddy, backups, subscription-page | this file |
| 🛰 **remnanode.sh** | `4.6.0` | Node: Xray-core, logs, auto-restart | this file |
| 🎭 **selfsteal.sh** | `2.11.1` | Caddy masking for Reality, 11 website templates | [README-selfsteal](./README-selfsteal.md) |
| 🌐 **wtm.sh** | `1.5.2` | WARP + Tor: WireGuard outbound for Xray, WARP+ | [README-warp](./README-warp.md) |
| 🐦 **netbird.sh** | `2.0.0` | NetBird mesh VPN: CLI / cloud-init / Ansible | [README-netbird](./README-netbird.md) |

Every script keeps itself up to date: it checks its own version on `update` (and when the menu
opens), applies a newer one **without asking**, and re-runs your command. Downloads try GitHub
first, then jsDelivr mirrors. To install or refresh just the CLI on a server, use
`install-script` — see the command tables below.

---

## 🚀 Remnawave Panel

<div align="center"><img src="assets/preview-remnawave.svg" alt="remnawave menu" width="640"></div>

- **Turnkey install** — `.env`, secrets, ports, compose, and the admin account are generated automatically (credentials in `admin-credentials.txt`)
- **Subscription link format** — pick `nanoid` (16..64 chars), `uuid` or your own pattern at install time; `update` writes the block into an existing `.env` and offers the same choice. Patterns are validated exactly like the panel does, with a live sample (panel 3.4.0+)
- **Caddy reverse proxy** — auto-SSL, optional authentication portal with MFA (Caddy Security)
- **Subscription-page** — alongside the panel or standalone on a separate server; API token created automatically with least-privilege scopes
- **Safe `update`** — DB + config snapshot before every update, plus automatic migrations (including v2 → v3)
- **Telegram** — notifications and backup delivery, thread, proxy and custom Bot API address support (self-hosted server or relay)

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
| `upgrade-postgres` | Optional PostgreSQL 17 → 18 upgrade (dump → fresh volume → restore, with rollback) |
| `edit` / `edit-env` / `console` | compose, .env, panel console |
| `subpage` / `subpage-token` / `subpage-restart` | Subscription-page management |
| `install-subpage-standalone --with-caddy` | Subpage on a separate server |
| `caddy …` | Caddy install & management (`up/down/logs/edit/reset-user`) |
| `install-script` / `update-script` | Install or refresh **the CLI itself** — no containers touched |
| `uninstall-script` | Remove the CLI from `/usr/local/bin` |

> `install-script` is not `install`. It only puts (or refreshes) the `remnawave` command on the
> server — useful before the panel exists, on a box you only manage remotely, or to force the newest
> CLI right now. `install` sets up the panel itself.
> `update` refreshes the CLI on its own before doing anything else, so you rarely need to call these
> by hand. All downloads try GitHub first, then jsDelivr mirrors.

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-script
# GitHub blocked? same thing via a mirror:
sudo bash <(curl -Ls https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/remnawave.sh) @ install-script
```

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

<div align="center"><img src="assets/preview-remnanode.svg" alt="remnanode menu" width="640"></div>

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
| `--port=PORT` / `--xtls-port=PORT` | NODE_PORT (3000) / legacy XTLS_API_PORT (61000, ignored by node 2.8.0+) |
| `--xray` / `--no-xray` | Whether to install Xray-core |
| `--name NAME` / `--dev` | Directory name / dev image |
| `--tag VERSION` | Pin the node image, e.g. `--tag 3.4.1`. Exact versions only: the node has no floating `2`/`3` tags. A pinned node is not moved by `update`; `update --tag VERSION` re-pins an existing install |

> ⚠️ **Only node 3.3.0 … 3.3.2 require panel 3.3.0+.** Those releases reject the TLS handshake
> unless the panel presents a derived SNI, so such a node on an older panel just shows up as offline
> (`unknown sni` in the node logs). The installer asks about this once, and only when the requested
> tag falls inside that window. Node 3.4.0+ hides the check behind `SNI_VERIFICATION` (off by
> default), so `latest` runs fine on any panel; set `SNI_VERIFICATION=true` in the node `.env` to
> turn it back on when your panel is 3.3.0 or newer.
>
> `up` / `restart` never change the running image — only `update` does. The CLI itself, on the other
> hand, keeps itself current automatically (mirrored via jsDelivr when GitHub is unreachable).

| Command | Description |
|---|---|
| `install` / `uninstall` / `update` | Lifecycle |
| `up` / `down` / `restart` / `status` / `logs` | Service management |
| `core-update` | Xray-core update |
| `xray_log_out` / `xray_log_err` | Real-time Xray logs |
| `setup-logs` / `auto-restart` | Log rotation / scheduled auto-restart |
| `install-script` | Install or refresh **the CLI itself** — no containers touched |
| `uninstall-script` | Remove the CLI from `/usr/local/bin` |

> `install-script` is not `install`. It only puts (or refreshes) the `remnanode` command on the
> server — useful before a node exists, or to force the newest CLI right now. `install` sets up the
> node container. `update` refreshes the CLI on its own first, so you rarely need this by hand.

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install-script
# GitHub blocked? same thing via a mirror:
sudo bash <(curl -Ls https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/remnanode.sh) @ install-script
```

```text
/opt/remnanode/            # .env, docker-compose.yml
/var/lib/remnanode/        # Xray binary
/usr/local/bin/remnanode   # CLI command
```

</details>

---

## 🎭 Caddy Selfsteal

<div align="center"><img src="assets/preview-selfsteal.svg" alt="selfsteal menu" width="640"></div>

- **11 website templates** for camouflage: social, converters, file clouds, speedtest, and more
- **Anti-fingerprint** — every template is uniquified on install (no byte-identical copies), provenance traces stripped
- **Built-in guide** for Reality integration (`selfsteal guide`)
- **Certificate check** in the menu and `status`: issued for the current domain, publicly trusted, days left (Caddy's ACME cert is read from its Docker volume)

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

<div align="center"><img src="assets/preview-wtm.svg" alt="wtm menu" width="640"></div>

- **WARP** as a native WireGuard outbound for Xray (no TUN interface) + **WARP+** support
- **Tor** SOCKS5 proxy and `.onion` routing through Xray
- Connection tests, watchdog, ready-to-paste Xray config snippets

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script
sudo wtm    # menu; or: wtm install-all / warp-plus / status
```

Full documentation: **[README-warp.md](./README-warp.md)**

## 🐦 NetBird

<div align="center"><img src="assets/preview-netbird.svg" alt="netbird menu" width="640"></div>

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
