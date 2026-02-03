# Add New Script

> Use this prompt when creating a new bash script for the repository.

## Context Required

Before proceeding, provide:
- Script name and purpose
- Target audience (end-user / developer / admin)
- Required dependencies
- Expected CLI interface

## Workflow

### 1. Plan

Create implementation plan:

```markdown
## Implementation Plan

### Purpose
[One sentence describing what this script does]

### Dependencies
- [ ] curl
- [ ] jq
- [ ] docker compose

### CLI Interface
```
script.sh <command> [options]
  install   — Install the service
  up        — Start containers
  down      — Stop containers
  --help    — Show help
```

### Functions to Implement
1. `main()` — Entry point
2. `check_dependencies()` — Validate requirements
3. `install_command()` — Installation logic
4. `usage()` — Help output

### Files Created/Modified
- `/opt/service/.env` — Environment config
- `/opt/service/docker-compose.yml` — Container definition
```

### 2. Diff

Show the complete script with:

```bash
#!/usr/bin/env bash
# Script: new-script.sh
# VERSION=1.0.0
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"

# ... full implementation
```

### 3. Verification

Provide commands to verify:

```bash
# Syntax check
bash -n script.sh

# Linting
shellcheck script.sh

# Help works
./script.sh --help

# Dry run (if applicable)
./script.sh install --dry-run
```

## Script Header Template

Every script MUST include repository and author info:

```bash
#!/usr/bin/env bash
# Script: script-name.sh
# Repository: https://github.com/DigneZzZ/remnawave-scripts
# Author: DigneZzZ
# VERSION=1.0.0
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_URL="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/script-name.sh"
```

## Documentation Launch Format

In README and docs, ALWAYS use this one-liner format:

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/script.sh) @ command
```

## Interactive Menu Design

### Menu Header Pattern
```bash
echo -e "\033[1;37m⚡ $APP_NAME Panel Management\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
```

### Service Status Display
```bash
# Running service
echo -e "\033[1;32m✅ Service: Running\033[0m"

# Stopped service  
echo -e "\033[1;31m❌ Service: Stopped\033[0m"

# Not installed
echo -e "\033[1;33m⚠️  Service: Not installed\033[0m"

# Feature enabled/disabled
echo -e "Feature: $([ "$enabled" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
```

### Menu Items Format
```bash
echo -e "\033[1;37m📊 Section Title:\033[0m"
echo -e "   \033[38;5;15m1)\033[0m 📊 Status"
echo -e "   \033[38;5;15m2)\033[0m 📋 Logs"
echo -e "   \033[38;5;15m3)\033[0m 🩺 Health check"
```

### Status Icons Reference
| Icon | Meaning | Color Code |
|------|---------|------------|
| ✅ | Running/Enabled | `\033[1;32m` (green) |
| ❌ | Stopped/Disabled | `\033[1;31m` (red) |
| ⚠️ | Warning/Not installed | `\033[1;33m` (yellow) |
| 📊 | Status/Monitoring | — |
| 📋 | Logs | — |
| 🩺 | Health check | — |
| ⚡ | Main header | — |

## Checklist

- [ ] Has `set -Eeuo pipefail`
- [ ] Has `trap` for error handling
- [ ] Has `usage()` function
- [ ] Has `check_dependencies()`
- [ ] Uses `docker compose` (not `docker-compose`)
- [ ] No hardcoded secrets
- [ ] Idempotent operations
- [ ] Passes `shellcheck`
- [ ] Has repository/author header
- [ ] Menu uses standard status icons
