# Release Notes

> Use this prompt to generate release notes for a new version.

## Context Required

Before proceeding, provide:
- Version number (e.g., 5.9.0)
- Git range (e.g., v5.8.0..HEAD)
- Release type (major/minor/patch)

## Workflow

### 1. Plan

Analyze changes and categorize:

```markdown
## Release Analysis

### Version: X.Y.Z
### Type: [Major|Minor|Patch]

### Change Categories
1. **Features** — New functionality
2. **Improvements** — Enhanced existing features
3. **Fixes** — Bug fixes
4. **Security** — Security patches
5. **Breaking** — Incompatible changes

### Commits to Review
```bash
git log --oneline v5.8.0..HEAD
```
```

### 2. Release Notes (Diff)

Generate formatted release notes:

```markdown
# Release vX.Y.Z

> Released: YYYY-MM-DD

## ⚠️ Breaking Changes
- None (or list changes requiring user action)

## ✨ Features
- Added `command` for doing X (#123)
- New `--flag` option for Y

## 🔧 Improvements
- Improved performance of backup operations
- Better error messages for failed connections

## 🐛 Fixes
- Fixed issue where restore failed on empty database
- Resolved race condition in container startup

## 🔒 Security
- Updated base images to patch CVE-XXXX-YYYY
- Added input validation for user-provided paths

## 📦 Dependencies
- Requires Docker Compose v2.20+
- Tested on Ubuntu 22.04, 24.04, Debian 12

## Upgrade Instructions
```bash
# Download latest
curl -sL <url> -o remnawave.sh

# Update
bash remnawave.sh update
```
```

### 3. Verification

```bash
# Verify version bump in script
grep "SCRIPT_VERSION" remnawave.sh

# Verify changelog matches commits
git log --oneline v5.8.0..HEAD | wc -l

# Test upgrade path
./remnawave.sh --version
./remnawave.sh update --dry-run
```

## Release Checklist

- [ ] Version bumped in script (`SCRIPT_VERSION="X.Y.Z"`)
- [ ] Version comment updated (`# VERSION=X.Y.Z`)
- [ ] Breaking changes documented with migration steps
- [ ] Security issues disclosed responsibly
- [ ] Tested on target platforms
- [ ] README updated if needed
- [ ] Tag created: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
