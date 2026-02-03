# Refactor Script

> Use this prompt when improving or refactoring an existing script.

## Context Required

Before proceeding, provide:
- Script file path
- Specific areas to refactor (or "full review")
- Constraints (preserve backward compatibility, etc.)

## Workflow

### 1. Plan

Analyze current state and propose changes:

```markdown
## Refactoring Plan

### Current Issues
1. [Issue 1: e.g., "Missing error handling in install_command()"]
2. [Issue 2: e.g., "Duplicated code in menu functions"]
3. [Issue 3: e.g., "Uses deprecated docker-compose"]

### Proposed Changes
| Area | Current | Proposed | Impact |
|------|---------|----------|--------|
| Error handling | None | Add trap + error_handler | Low risk |
| Docker | `docker-compose` | `docker compose` | Breaking for Docker v1 |
| Logging | echo statements | print_* functions | No breaking |

### Risk Assessment
- **Low**: Logging, formatting changes
- **Medium**: Function restructuring
- **High**: CLI interface changes
```

### 2. Diff

Show changes in git diff format:

```diff
@@ -10,6 +10,8 @@
 #!/usr/bin/env bash
+set -Eeuo pipefail
+trap 'error_handler $? $LINENO' ERR

@@ -45,7 +47,7 @@
-    docker-compose up -d
+    docker compose up -d
```

### 3. Verification

```bash
# Diff check
git diff script.sh

# Syntax validation
bash -n script.sh

# Lint
shellcheck script.sh

# Functional test
./script.sh --help
./script.sh <test-command>

# Compare behavior (if applicable)
./script.sh install --dry-run 2>&1 | diff - expected-output.txt
```

## Refactoring Priorities

1. **Security** — Remove hardcoded secrets, add input validation
2. **Reliability** — Add error handling, make idempotent
3. **Maintainability** — Extract functions, reduce duplication
4. **Compatibility** — Use `docker compose` v2

## Checklist

- [ ] No breaking changes to CLI interface (or documented)
- [ ] Error handling added/improved
- [ ] Uses `docker compose` (v2)
- [ ] No new ShellCheck warnings
- [ ] Tested on target OS (Ubuntu 22.04+)
