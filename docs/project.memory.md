# Project Memory — Decision Log

Architectural and technical decisions log for context preservation between sessions.

---

## Record Template

### [YYYY-MM-DD] Decision Title
**Context:** Why the decision was needed  
**Decision:** What was chosen  
**Alternatives:** What was considered  
**Rationale:** Why this was selected  
**Consequences:** What changed as a result

---

## Records

### [2025-03-11] Project Initialization
**Context:** Need for automated Remnawave Panel deployment  
**Decision:** Created bash-based installer scripts  
**Alternatives:** Ansible, Terraform, Python scripts  
**Rationale:** Bash is universally available, no additional dependencies  
**Consequences:** Single-file deployment possible via curl pipe

---

### [2025-06-15] Docker Compose v2 Migration
**Context:** Docker deprecated standalone `docker-compose` binary  
**Decision:** Migrate all scripts to use `docker compose` (plugin syntax)  
**Alternatives:** Keep supporting both  
**Rationale:** v1 is deprecated, v2 is default in modern Docker  
**Consequences:** Requires Docker 20.10+ with compose plugin

---

### [2025-09-20] Bilingual Localization System
**Context:** Users from different regions need native language support  
**Decision:** Variable-based lookup system (`L_en_*`, `L_ru_*`)  
**Alternatives:** gettext, separate scripts per language  
**Rationale:** No external dependencies, easy to extend  
**Consequences:** All user-facing strings centralized, ~200 translation keys

---

### [2026-02-03] Copilot Configuration Structure
**Context:** Need for consistent AI-assisted development  
**Decision:** Created `.github/` structure with instructions, prompts, docs  
**Alternatives:** Single instruction file  
**Rationale:** Modular approach, domain-specific guidance  
**Consequences:** Improved code generation quality, standardized workflows

---

## Pending Decisions

### [ ] CI/CD Pipeline
**Status:** Not implemented  
**Options:** GitHub Actions with ShellCheck, basic testing  
**Blockers:** None

### [ ] Automated Testing
**Status:** Under consideration  
**Options:** bats-core, shunit2  
**Blockers:** Time investment for test coverage
