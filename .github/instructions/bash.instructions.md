# Bash Script Standards

> Apply to all `*.sh` files in this repository.

## Required Header

Every script MUST start with:

```bash
#!/usr/bin/env bash
# Script: <name>.sh
# VERSION=X.Y.Z
set -Eeuo pipefail

SCRIPT_VERSION="X.Y.Z"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

## Versioning

### Semantic Versioning (SemVer)
Follow `MAJOR.MINOR.PATCH` format:
- **MAJOR** — Breaking changes (CLI interface, config format)
- **MINOR** — New features, backward compatible
- **PATCH** — Bug fixes, documentation

### Dual Version System
Each script requires **both** version markers:

```bash
# VERSION=5.8.0          # Comment: grep-based detection for remote updates
SCRIPT_VERSION="5.8.0"   # Variable: runtime access
```

**Why dual?**
- Comment `# VERSION=` — parsed by update checker via `grep` (no bash execution)
- Variable `SCRIPT_VERSION=` — used in script logic, `--version` output

### Version Update Checklist
When releasing a new version:
1. Update `# VERSION=X.Y.Z` comment (line 3-5)
2. Update `SCRIPT_VERSION="X.Y.Z"` variable
3. Update `README.md` badge if applicable
4. Update `BACKUP_SCRIPT_VERSION` if backup script embedded
5. Commit with message: `Release vX.Y.Z: <summary>`
6. Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`

### Version Locations
| Script | Comment Line | Variable Line |
|--------|--------------|---------------|
| `remnawave.sh` | ~4 | ~6 |
| `remnanode.sh` | ~3 | ~4 |
| `selfsteal.sh` | ~3 | ~4 |

## Error Handling

```bash
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

error_handler() {
    local exit_code=$1 line=$2 command=$3
    echo "ERROR: Command '$command' failed with exit code $exit_code at line $line" >&2
    exit "$exit_code"
}
```

## Dependency Checking

Check required tools at script start:

```bash
check_dependencies() {
    local deps=(curl jq docker)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: Required command '$cmd' not found" >&2
            exit 1
        fi
    done
    # Docker Compose v2 check
    if ! docker compose version &>/dev/null; then
        echo "ERROR: Docker Compose v2 plugin required" >&2
        exit 1
    fi
}
```

## Usage/Help Function

Every script with CLI arguments MUST have:

```bash
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
    install     Install the service
    up          Start containers
    down        Stop containers
    --help      Show this help

Examples:
    $(basename "$0") install
    $(basename "$0") up --force
EOF
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
```

## Parameter Validation

```bash
validate_params() {
    [[ -z "${1:-}" ]] && { echo "ERROR: Command required" >&2; usage; exit 1; }
    case "$1" in
        install|up|down|restart) ;;
        *) echo "ERROR: Unknown command '$1'" >&2; usage; exit 1 ;;
    esac
}
```

## Docker Compose

- **ALWAYS** use `docker compose` (v2), NOT `docker-compose`
- Use `docker compose` for all operations:
  ```bash
  docker compose up -d
  docker compose down
  docker compose logs -f
  docker compose ps
  ```

## Idempotency

Scripts must be safe to run multiple times:

```bash
# Good: Check before creating
[[ -d "$TARGET_DIR" ]] || mkdir -p "$TARGET_DIR"

# Good: Use --ignore-existing or similar flags
docker network create "$NETWORK" 2>/dev/null || true
```

## Logging

Use consistent output functions:

```bash
print_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
print_success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
print_warning() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
```

## Security

- **NEVER** hardcode secrets — use environment variables
- **NEVER** log secrets — mask sensitive output
- Use `chmod 600` for files containing credentials
- Validate all user input before use

## Testing Checklist

- [ ] `shellcheck script.sh` passes
- [ ] `bash -n script.sh` (syntax check) passes
- [ ] `script.sh --help` works
- [ ] Script is idempotent (safe to re-run)
