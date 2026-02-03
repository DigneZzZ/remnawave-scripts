# Documentation Standards

> Apply to all `*.md` files in this repository.

## Document Structure

Every documentation file MUST follow this order:

```markdown
# Title

> **TL;DR:** One-sentence summary of what this does.

## Usage

Quick start commands — copy-paste ready.

## Examples

Real-world usage scenarios with expected output.

## Configuration

Environment variables, config files, options.

## FAQ

Common questions and troubleshooting.

## Security

Security considerations and best practices.
```

## TL;DR Section

**Required** at the top of every doc:

```markdown
> **TL;DR:** Install Remnawave Panel with one command: `bash <(curl -sL url) install`
```

## Usage Section

- Show the most common use case first
- Use code blocks with copy-paste ready commands
- Include expected output where helpful

```markdown
## Usage

### Quick Install
```bash
bash remnawave.sh install
```

### With Options
```bash
bash remnawave.sh install --dev --force
```
```

## Examples Section

- Show 2-3 real scenarios
- Include both command and expected result
- Use descriptive headers

## FAQ Section

Format as expandable details or simple Q&A:

```markdown
## FAQ

### How do I update?
Run `remnawave update` — this pulls latest images and restarts.

### Where are logs stored?
View with `docker compose logs -f` or check `/opt/remnawave/logs/`.
```

## Security Section

**Required** for any script that:
- Handles credentials
- Modifies system configuration
- Runs with elevated privileges

Include:
- What permissions are needed
- Where secrets are stored
- How to rotate credentials

## Style Guidelines

| Element | Format |
|---------|--------|
| Commands | `` `code blocks` `` |
| File paths | `` `/opt/remnawave/.env` `` |
| Variables | `` `$VAR` `` or `` `${VAR}` `` |
| Emphasis | **bold** for warnings, *italic* for notes |

## Language

- Write in English (primary) or Russian (for `*_RU.md` files)
- Use active voice: "Run the command" not "The command should be run"
- Be concise: prefer bullet points over paragraphs
