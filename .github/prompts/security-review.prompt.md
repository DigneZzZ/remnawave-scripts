# Security Review

> Use this prompt to perform a security audit of a script.

## Context Required

Before proceeding, provide:
- Script file path(s) to review
- Deployment context (user-facing, internal, privileged)
- Known sensitive data handled

## Workflow

### 1. Plan

Outline security review scope:

```markdown
## Security Review Plan

### Scope
- [ ] Input validation
- [ ] Secret handling
- [ ] File permissions
- [ ] Network operations
- [ ] Privilege escalation
- [ ] Command injection
- [ ] Path traversal

### Threat Model
| Asset | Threat | Likelihood | Impact |
|-------|--------|------------|--------|
| .env files | Exposure | Medium | High |
| Admin credentials | Leakage | Low | Critical |
| Docker socket | Escape | Low | Critical |
```

### 2. Findings (Diff format)

Report issues with severity and fix:

```markdown
## Findings

### [CRITICAL] Hardcoded credentials
**Location:** line 45
**Issue:** API token stored in script
**Fix:**
```diff
-API_TOKEN="sk-secret-token"
+API_TOKEN="${API_TOKEN:?ERROR: API_TOKEN not set}"
```

### [HIGH] Missing input validation
**Location:** line 120
**Issue:** User input passed directly to command
**Fix:**
```diff
-rm -rf "$USER_INPUT"
+[[ "$USER_INPUT" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Invalid input"; exit 1; }
+rm -rf "/safe/path/$USER_INPUT"
```

### [MEDIUM] Insecure file permissions
**Location:** line 80
**Issue:** Credentials file world-readable
**Fix:**
```diff
 echo "$PASSWORD" > credentials.txt
+chmod 600 credentials.txt
```
```

### 3. Verification

```bash
# Check for hardcoded secrets
grep -rn "password\|token\|secret\|key" script.sh

# Check file permission operations
grep -n "chmod\|chown" script.sh

# Check for unsafe variable usage
shellcheck -e SC2086 script.sh

# Check for command injection vectors
grep -n 'eval\|$(\|`' script.sh
```

## Security Checklist

### Secrets
- [ ] No hardcoded passwords/tokens/keys
- [ ] Secrets loaded from environment only
- [ ] Secrets not logged or echoed
- [ ] Credential files have 600 permissions

### Input Validation
- [ ] All user input validated before use
- [ ] No direct use in `rm`, `eval`, `exec`
- [ ] Path traversal prevented

### Execution
- [ ] Minimal privilege required
- [ ] `sudo` used only where necessary
- [ ] No unnecessary network exposure

### Docker
- [ ] Images from trusted sources
- [ ] No `--privileged` unless required
- [ ] Secrets via Docker secrets or env, not build args
