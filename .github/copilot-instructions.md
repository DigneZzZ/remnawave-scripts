# Copilot Instructions for remnawave-scripts

> **Related docs:** [bash.instructions.md](instructions/bash.instructions.md) | [docs.instructions.md](instructions/docs.instructions.md) | [project.context.md](../docs/project.context.md)

## Repository Info

| Field | Value |
|-------|-------|
| **Repository** | `github.com/DigneZzZ/remnawave-scripts` |
| **Author** | DigneZzZ |
| **License** | MIT |
| **Language** | Bash (100%) |

## Project Overview

Enterprise-grade Bash scripts (~25K LOC) for **Remnawave Panel**, **RemnaNode**, and **Reality traffic masking**. Docker-based deployments with backup/restore, Telegram integration, and cron scheduling.

## Script Launch Format

### One-liner Installation (ALWAYS use this format in docs)
```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/SCRIPT.sh) @ COMMAND
```

### Examples
```bash
# Remnawave Panel
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-subpage-standalone

# RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Selfsteal
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh)
```

### URL Pattern
```
https://github.com/DigneZzZ/remnawave-scripts/raw/main/{script}.sh
```

## ⚠️ Critical Rules

### Docker Compose v2 — MANDATORY
```bash
# ✅ ALWAYS use plugin syntax
docker compose up -d
docker compose logs -f

# ❌ NEVER use deprecated standalone
docker-compose up -d  # WRONG
```

### No Secrets in Code
- All credentials via `.env` files or environment variables
- Use `${VAR:-default}` for safe defaults
- Credential files: `chmod 600`

### Git Workflow — MANDATORY

The `main` branch is **protected** (branch protection rules, Code Scanning). **Never push directly to `main`.**

#### Creating a PR for changes

1. **Create a feature branch** from the current `main`:
   ```bash
   git checkout -b <type>/<short-description>
   # Examples: fix/docker-pull-retry, feat/backup-encryption, docs/update-readme
   ```

2. **Commit changes** with a conventional commit message:
   ```bash
   git add <files>
   git commit -m "<type>(<scope>): <summary>

   - Detail 1
   - Detail 2"
   ```
   Types: `fix`, `feat`, `docs`, `refactor`, `chore`
   Scopes: `remnawave`, `remnanode`, `selfsteal`, `backup`, `wtm`, `netbird`

3. **Push the branch** to remote:
   ```bash
   git push origin <branch-name>
   ```

4. **Create a Pull Request** using `gh` CLI:
   ```bash
   gh pr create --base main --head <branch-name> \
     --title "<type>(<scope>): <summary>" \
     --body-file /tmp/pr-body.md
   ```
   If `gh` is not installed: `brew install gh && gh auth login --web`

5. **PR body template** — save to a temp file, then pass via `--body-file`:
   ```markdown
   ## Problem
   Brief description of the issue.

   ## Solution
   What was changed and why.

   ## Changes
   - file1: description
   - file2: description
   ```

#### Branch naming convention
| Type | Example |
|------|---------|
| Bug fix | `fix/docker-pull-retry` |
| Feature | `feat/telegram-threads` |
| Documentation | `docs/update-readme` |
| Refactor | `refactor/env-generation` |

### README Sync — MANDATORY
When modifying or improving any script, **always update its corresponding README** file if it exists.

| Script | README |
|--------|--------|
| `remnawave.sh` | `README.md` + `README_RU.md` |
| `remnanode.sh` | `README.md` (section) |
| `selfsteal.sh` | `README-selfsteal.md` |
| `netbird.sh` | `README-netbird.md` |
| `wtm.sh` | `README-warp.md` |
| `remnawave-backup.sh` | `README.md` (section) |
| `restore.sh` | `README.md` (section) |

**Update checklist:**
- Sync feature lists (EN/RU versions must match)
- Update version references if changed
- Add new CLI options/commands to tables
- Update examples if behavior changed

## Architecture

### Script Structure
| Script | Lines | Pattern | Entry Point |
|--------|-------|---------|-------------|
| `remnawave.sh` | ~12.8K | CLI commands | `main()` at EOF |
| `remnanode.sh` | ~3.5K | CLI commands | `main()` at EOF |
| `selfsteal.sh` | ~4.8K | Interactive menu | `main_menu()` |

### Function Naming
```bash
*_command()     # CLI entry: install_command(), backup_command()
*_menu()        # Interactive: main_menu(), caddy_menu()
check_*()       # Validation: check_dependencies(), check_docker()
print_*()       # Output: print_info(), print_error()
```

### Localization System
~200 translation keys using variable lookup:
```bash
L_en_MENU_TITLE="Main Menu"
L_ru_MENU_TITLE="Главное меню"
L() { local var="L_${MENU_LANG}_${1}"; echo "${!var:-$1}"; }
# Usage: echo "$(L MENU_TITLE)"
```

### Version Tracking (dual system)
```bash
# VERSION=5.8.0          # grep-based detection for remote updates
SCRIPT_VERSION="5.8.0"   # Runtime variable
```

## Docker Compose Generation

### Heredoc Escaping Rules
When generating `docker-compose.yml` in heredocs:
```bash
# ${VAR}      → Bash substitutes NOW (container names, ports)
# \${VAR}     → Writes ${VAR} → docker compose reads from .env
# \$\${VAR}   → Writes $${VAR} → passed to container shell
```

### Service Dependencies
```
PostgreSQL (:6767→5432) ──┬──→ remnawave (:3000) ──→ subscription-page (:3010)
Redis                   ──┘
```

### YAML Anchors Pattern
```yaml
x-common: &common
    ulimits: { nofile: { soft: 1048576, hard: 1048576 } }
    restart: always
```

## Key Commands

```bash
# Installation
remnawave install [--dev] [--name custom]
remnanode install [--force]

# Operations
remnawave up|down|restart|status|logs
remnawave backup [--compress] [--telegram]
remnawave restore <file>
remnawave caddy install|up|down|logs

# Development
shellcheck *.sh                    # Lint all scripts
bash -n script.sh                  # Syntax check
./remnawave.sh --help              # Show usage
```

## Files Generated

| Path | Purpose |
|------|---------|
| `/opt/remnawave/.env` | Main panel config |
| `/opt/remnawave/.env.subscription` | Subscription page config |
| `/opt/remnawave/docker-compose.yml` | Container orchestration |
| `/opt/remnawave/admin-credentials.txt` | Auto-generated creds |
| `/opt/remnawave/backup-config.json` | Scheduled backup settings |

## Common Patterns

### Idempotent Operations
```bash
[[ -d "$DIR" ]] || mkdir -p "$DIR"
docker network create "$NET" 2>/dev/null || true
```

### User Prompts with Defaults
```bash
read -rp "Enter port [3000]: " port
port="${port:-3000}"
```

### Container Health Checks
```yaml
healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
    interval: 30s
    start_period: 30s
```

## Testing

- Target: Ubuntu 22.04+, Debian 12+
- Required: Docker with Compose v2 plugin
- Validate: `shellcheck --severity=warning *.sh`
- Use `--dev` flag for development images

## Telegram Integration

Backup system supports Telegram notifications via `backup-config.json`:

```json
{
  "telegram": {
    "enabled": true,
    "bot_token": "123456:ABC-DEF...",
    "chat_id": "-1001234567890",
    "thread_id": null,
    "api_server": "https://api.telegram.org",
    "send_files": true
  }
}
```

### Key Features
- **Large file support**: Auto-splits files >50MB into chunks
- **Thread support**: Use `thread_id` for topic-based group chats
- **Test delivery**: `remnawave schedule test-telegram`
- **Scheduled backups**: Automatic Telegram delivery via cron

### API Calls Pattern
```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@${FILE_PATH}" \
    -F "caption=${MESSAGE}"
```

## Upstream Sync

When updating docker-compose templates, sync with:
- https://github.com/remnawave/backend/blob/main/docker-compose-prod.yml
- https://github.com/remnawave/backend/blob/main/.env.sample
