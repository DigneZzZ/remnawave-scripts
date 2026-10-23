# tests

Plain-shell test suites (no bats required — `bash tests/run-tests.sh` is enough).

```bash
bash tests/run-tests.sh            # everything
bash tests/test-caddy-safety.sh    # one suite
```

## How they load the code under test

Production code is read straight out of `remnawave.sh`; nothing is copied. The
script marks the regions the tests need:

```bash
# ===== TESTABLE-BLOCK: <name> =====
...
# ===== END TESTABLE-BLOCK: <name> =====
```

`load_blocks <name>...` in `lib/harness.sh` extracts and sources them. Marker
matching (rather than brace matching) is deliberate: the Caddyfile templates are
heredocs full of lines that are a bare `}` in column 0.

Blocks: `managed-files`, `caddyfile-template`, `caddy-safety`, `caddyfile-migration`.

## Suites

| Suite | Covers |
|---|---|
| `test-managed-files.sh` | ownership marker, sha256 sidecar, backup rotation, the guarded-write decision table |
| `test-caddy-safety.sh` | domain collection, catch-all opt-in, validate-before-reload, health check, automatic rollback, and the 11.09 incident replayed through `migrate_caddyfile` |
| `test-no-unguarded-writes.sh` | structural scan: every write to a managed config path must be gated |
| `test-remnanode-version.sh` | old package-based and new bundled node versions, menu/status output with built-in or external Xray, and missing metadata |

The RemnaNode suite loads functions directly from `remnanode.sh`. It runs the real
version parser in Node.js with fixture files and replaces only the Docker boundary;
it does not start or modify containers. This suite needs Node.js on the test host
and reports a skip when it is unavailable.

`docker` and `curl` are stubbed through a `PATH` shim per sandbox, driven by
`STUB_CADDY_RUNNING`, `STUB_VALIDATE_EXIT`, `STUB_RELOAD_EXIT`,
`STUB_DEAD_DOMAINS` and `STUB_DEAD_AFTER_RELOAD`.

## Seeing a suite fail

`test-no-unguarded-writes.sh` takes an optional path, so it can be pointed at the
revision that caused the outage:

```bash
git show <pre-fix-rev>:remnawave.sh > /tmp/old.sh
bash tests/test-no-unguarded-writes.sh /tmp/old.sh   # reports all 15 unguarded writes
```
