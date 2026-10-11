#!/usr/bin/env bash
# validate-before-reload, health-check-after-reload, automatic rollback and the
# catch-all block that used to swallow every domain the template forgot.
. "$(cd "$(dirname "$0")" && pwd)/lib/harness.sh"
SUITE_NAME="caddy-safety"

load_blocks "managed-files" "caddyfile-template" "caddy-safety" "caddyfile-migration"

SCRIPT_VERSION="6.8.0"
ASSUME_YES="true"
STRICT_MODE="false"
APP_NAME="remnawave"

echo "== $SUITE_NAME =="

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
cp "$REPO_ROOT/tests/fixtures/user-caddyfile" "$CADDY_DIR/Caddyfile"

it "every domain in .env is collected for the health check"
domains=$(caddy_config_domains "$CADDY_DIR/Caddyfile" "$CADDY_DIR/.env")
assert_eq "$(echo "$domains" | grep -c .)" "8"

it "the subscription mirrors are part of the collected set"
assert_contains "$domains" "sub-fb.example.com"
it "the second panel domain is part of the collected set"
assert_contains "$domains" "panel2.example.com"
it "unresolved {\$VAR} placeholders are not probed as hostnames"
assert_not_contains "$domains" '{$'
it "the :443 catch-all address is not probed as a hostname"
assert_not_contains "$domains" ":443"

it "literal hostnames written directly in the Caddyfile are collected too"
printf '\nhttps://extra.example.com {\n    respond 200\n}\n' >> "$CADDY_DIR/Caddyfile"
assert_contains "$(caddy_config_domains "$CADDY_DIR/Caddyfile" "$CADDY_DIR/.env")" "extra.example.com"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
it "the generated template has no catch-all by default"
CADDY_CATCH_ALL="false"
CADDYFILE_OUT="$SANDBOX/gen" create_simple_caddyfile "panel.example.com" "sub.example.com" "sub"
assert_not_contains "$(cat "$SANDBOX/gen")" ":443 {"

it "--catch-all adds the block explicitly"
CADDY_CATCH_ALL="true"
CADDYFILE_OUT="$SANDBOX/gen2" create_simple_caddyfile "panel.example.com" "sub.example.com" "sub"
assert_contains "$(cat "$SANDBOX/gen2")" ":443 {"

it "the catch-all aborts instead of answering 204 with a self-signed cert"
assert_contains "$(cat "$SANDBOX/gen2")" "abort"
it "the catch-all no longer responds 204"
assert_not_contains "$(cat "$SANDBOX/gen2")" "respond 204"
it "the catch-all carries a warning about unlisted SNI"
assert_contains "$(cat "$SANDBOX/gen2")" "SNI"

it "the secure template follows the same rule"
CADDY_CATCH_ALL="false"
CADDYFILE_OUT="$SANDBOX/gen3" create_secure_caddyfile "panel.example.com" "sub.example.com" "sub"
assert_not_contains "$(cat "$SANDBOX/gen3")" ":443 {"
CADDY_CATCH_ALL="false"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
it "a clean install writes, validates and reloads"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
assert_rc "$?" 0
it "the freshly generated file is owned by the script"
mf_is_ours "$CADDY_DIR/Caddyfile"; assert_success "$?"
it "caddy validate ran before the reload"
assert_contains "$(cat "$DOCKER_LOG")" "caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile"
it "caddy was reloaded exactly once"
assert_eq "$(reload_count)" "1"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
cp "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
rm -f "$SANDBOX/reload-count" "$SANDBOX/.reloaded"

it "a config caddy rejects never reaches a reload"
STUB_VALIDATE_EXIT=1
CADDY_CATCH_ALL="true"
out=$(caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" 2>&1); rc=$?
CADDY_CATCH_ALL="false"
assert_rc "$rc" 1
it "the previous config is restored byte-for-byte"
assert_files_identical "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
it "caddy is not reloaded with a broken config"
assert_eq "$(reload_count)" "0"
it "the rollback is reported to the operator"
assert_contains "$out" "Rolled back to"
it "the checksum still matches the restored file"
mf_is_ours "$CADDY_DIR/Caddyfile"; assert_success "$?"
STUB_VALIDATE_EXIT=0
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
cp "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
rm -f "$SANDBOX/reload-count" "$SANDBOX/.reloaded"

it "a domain that stops answering after the reload triggers a rollback"
STUB_DEAD_AFTER_RELOAD="sub.example.com"
CADDY_CATCH_ALL="true"
out=$(caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" 2>&1); rc=$?
CADDY_CATCH_ALL="false"
assert_rc "$rc" 1
it "the working config is restored"
assert_files_identical "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
it "caddy is reloaded a second time to apply the rollback"
assert_eq "$(reload_count)" "2"
it "the lost domain is named in the report"
assert_contains "$out" "sub.example.com"
STUB_DEAD_AFTER_RELOAD=""
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
rm -f "$SANDBOX/reload-count" "$SANDBOX/.reloaded"

it "a domain that was already down before the update does not block the update"
STUB_DEAD_DOMAINS="sub4.example.com"
CADDY_CATCH_ALL="true"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1; rc=$?
CADDY_CATCH_ALL="false"
assert_rc "$rc" 0
it "no rollback happened"
assert_eq "$(reload_count)" "1"
STUB_DEAD_DOMAINS=""
teardown_sandbox

# ---------------------------------------------------------------------------
# The production incident, end to end.
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
cp "$REPO_ROOT/tests/fixtures/user-caddyfile" "$CADDY_DIR/Caddyfile"
cp "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"

it "updating over a hand-maintained 8-domain config changes nothing"
out=$(caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" 2>&1)
assert_rc "$?" 2
it "the admin's Caddyfile is untouched"
assert_files_identical "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
it "caddy is never reloaded"
assert_eq "$(reload_count)" "0"
it "the proposed template is left as Caddyfile.new-<version>"
assert_file_exists "$CADDY_DIR/Caddyfile.new-6.8.0"
it "the operator gets a one-line rollback/apply hint"
assert_contains "$out" "Caddyfile.new-6.8.0"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
it "the rollback hint is a single copy-pasteable command"
b=$(mf_backup "$CADDY_DIR/Caddyfile")
hint=$(mf_restore_hint "$b" "$CADDY_DIR/Caddyfile" "$(caddy_reload_cmdline)")
assert_contains "$hint" "cp $b $CADDY_DIR/Caddyfile && docker exec caddy-remnawave caddy reload --config /etc/caddy/Caddyfile --force"
it "the hint fits on one line"
assert_eq "$(printf '%s' "$hint" | grep -c .)" "1"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
it "with caddy stopped the config is written but nothing is reloaded"
STUB_CADDY_RUNNING=0
caddy_write_config "simple" "panel.example.com" "sub.example.com" "sub" >/dev/null 2>&1
assert_rc "$?" 0
it "no reload is attempted against a stopped container"
assert_eq "$(reload_count)" "0"
STUB_CADDY_RUNNING=1
teardown_sandbox

# ---------------------------------------------------------------------------
# The 11.09 incident replayed through the real update-time migration.
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddy-env" "$CADDY_DIR/.env"
cp "$REPO_ROOT/tests/fixtures/user-caddyfile" "$CADDY_DIR/Caddyfile"
cp "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"

it "the update-time migration still recognises this config as outdated"
check_caddyfile_migration_needed; assert_success "$?"

it "but it no longer rewrites the admin's Caddyfile"
migrate_caddyfile > "$SANDBOX/out" 2>&1; rc=$?
assert_rc "$rc" 2
it "all eight site blocks survive byte-for-byte"
assert_files_identical "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
it "the subscription mirrors are still in the live config"
assert_contains "$(cat "$CADDY_DIR/Caddyfile")" "SUB_DOMAIN_FAILBACK"
it "the custom tls directives are still in the live config"
assert_contains "$(cat "$CADDY_DIR/Caddyfile")" "dns route53"
it "caddy is never reloaded during the migration"
assert_eq "$(reload_count)" "0"
it "the proposed template is offered as Caddyfile.new-<version>"
assert_file_exists "$CADDY_DIR/Caddyfile.new-6.8.0"
it "PANEL_HOST is still appended to .env (that part is additive and safe)"
assert_contains "$(cat "$CADDY_DIR/.env")" "PANEL_HOST="
teardown_sandbox

finish_suite
