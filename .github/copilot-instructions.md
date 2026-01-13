# Copilot Instructions for remnawave-scripts

## Project Overview
Collection of enterprise-grade Bash scripts for **Remnawave Panel**, **RemnaNode**, and **Reality traffic masking** management. Scripts are designed for Docker-based deployments with backup/restore, Telegram integration, and automated scheduling.

## Key Scripts Architecture

| Script | Purpose | Lines | Key Commands |
|--------|---------|-------|--------------|
| `remnawave.sh` | Main panel installer/manager | ~12K | `install`, `up`, `down`, `backup`, `restore`, `caddy`, `schedule` |
| `remnanode.sh` | Node installer/manager | ~3K | `install`, `up`, `down`, `update` |
| `selfsteal.sh` | Caddy/Nginx for Reality masking | ~4.4K | Menu-driven |
| `restore.sh` | Standalone restore utility | ~180 | Interactive |

## Code Patterns & Conventions

### Localization System (remnawave.sh)
Bilingual EN/RU support using variable-based lookup:
```bash
L_en_MENU_TITLE="Main Menu"
L_ru_MENU_TITLE="Главное меню"
L() { local var_name="L_${MENU_LANG}_${1}"; echo "${!var_name:-$1}"; }
# Usage: echo "$(L MENU_TITLE)"
```

### Docker Compose Generation
Generated docker-compose.yml uses YAML anchors for DRY:
```yaml
x-common: &common
    ulimits: { nofile: { soft: 1048576, hard: 1048576 } }
    restart: always
    networks: [ ${APP_NAME}-network ]
```

**Critical escaping rules in heredocs:**
- `${VAR}` → Bash substitutes at generation time (container names, host ports)
- `\${VAR}` → Writes `${VAR}` literally → docker-compose reads from .env
- `\$\${VAR}` → Writes `$${VAR}` → docker-compose passes `${VAR}` to container shell

### Version Management
Each script has dual version tracking:
```bash
# VERSION=5.7.0          # Comment for grep-based detection
SCRIPT_VERSION="5.7.0"   # Runtime variable
```

### CLI Command Structure
Scripts use positional command pattern:
```bash
remnawave <command> [--flags]
# Commands: install, up, down, restart, backup, restore, caddy, schedule, etc.
```

### Function Naming Conventions
- `*_command()` — CLI entry points (e.g., `install_command`, `backup_command`)
- `*_menu()` — Interactive menu handlers
- `schedule_*()` — Cron/scheduling related
- `subpage_*()` — Subscription page management

## Critical Implementation Details

### Healthcheck for remnawave container
Uses curl to METRICS_PORT endpoint:
```yaml
healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
    interval: 30s
    start_period: 30s
```

### Service Dependencies
```
remnawave-db (postgres) ← remnawave (backend) ← remnawave-subscription-page
remnawave-redis ←────────┘
```

### Default Ports
- Panel: 3000 (APP_PORT)
- Metrics: 3001 (METRICS_PORT)  
- Subscription: 3010 (SUB_PAGE_PORT)
- PostgreSQL: 6767 (host) → 5432 (container)

## Files Generated During Installation
| File | Purpose |
|------|---------|
| `/opt/remnawave/.env` | Main panel environment |
| `/opt/remnawave/.env.subscription` | Subscription page environment |
| `/opt/remnawave/docker-compose.yml` | Container orchestration |
| `/opt/remnawave/admin-credentials.txt` | Auto-generated admin creds |
| `/opt/remnawave/backup-config.json` | Scheduled backup settings |

## Testing Considerations
- Scripts are designed for Linux; test on Ubuntu 22.04+ or Debian 12+
- Docker and Docker Compose v2 required
- Use `--dev` flag with install for development branch images

## Common Modifications
When updating docker-compose template, sync with official:
- https://github.com/remnawave/backend/blob/main/docker-compose-prod.yml
- https://github.com/remnawave/backend/blob/main/.env.sample
