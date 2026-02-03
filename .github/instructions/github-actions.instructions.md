# GitHub Actions Standards

> Apply to all `.github/workflows/*.yml` files.

## Security First

### Minimal Permissions

Always declare explicit, minimal permissions:

```yaml
permissions:
  contents: read  # Only what's needed
```

For specific jobs:

```yaml
jobs:
  build:
    permissions:
      contents: read
      packages: write  # Only if publishing
```

### Never Log Secrets

```yaml
# ❌ NEVER do this
- run: echo "Token is ${{ secrets.API_TOKEN }}"

# ✅ Use secrets directly in commands
- run: curl -H "Authorization: Bearer ${{ secrets.API_TOKEN }}" ...
```

### Pin Actions to SHA

```yaml
# ❌ Avoid floating tags
- uses: actions/checkout@v4

# ✅ Pin to commit SHA
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

## Workflow Structure

```yaml
name: Descriptive Name

on:
  push:
    branches: [main]
    paths:
      - '*.sh'  # Only trigger on relevant changes
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run ShellCheck
        run: |
          shellcheck *.sh
```

## Docker Compose in CI

Use v2 plugin syntax:

```yaml
- name: Start services
  run: docker compose up -d

- name: Wait for healthy
  run: |
    timeout 60 bash -c 'until docker compose ps | grep -q healthy; do sleep 2; done'

- name: Stop services
  run: docker compose down -v
  if: always()
```

## ShellCheck Integration

```yaml
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      
      - name: Lint all scripts
        run: |
          find . -name "*.sh" -type f | xargs shellcheck --severity=warning
```

## Caching

```yaml
- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-
```

## Matrix Testing

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04]
    runs-on: ${{ matrix.os }}
```

## Required Checks

Recommended workflow triggers:
- `push` to `main` — full CI
- `pull_request` — validation only
- `schedule` — periodic security scans

## Secrets Management

- Store in GitHub Secrets, not in code
- Use environment-specific secrets: `PROD_*`, `DEV_*`
- Rotate regularly
- Audit access via GitHub audit log
