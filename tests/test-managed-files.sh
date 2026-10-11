#!/usr/bin/env bash
# Ownership marker, checksum sidecar, backups and the guarded-write decision
# table that keeps `update` from overwriting a hand-edited config.
. "$(cd "$(dirname "$0")" && pwd)/lib/harness.sh"
SUITE_NAME="managed-files"

load_blocks "managed-files"

SCRIPT_VERSION="6.8.0"
ASSUME_YES="true"      # tests run non-interactively
STRICT_MODE="false"

# A generator that renders a template into $1 (the mf_* contract).
fake_generator() {
    local out="$1" body="${2:-generated body}"
    printf '%s\n' "$body" > "$out"
}

echo "== $SUITE_NAME =="

# ---------------------------------------------------------------------------
setup_sandbox
it "mf_sidecar puts the checksum in a dotfile next to the target"
assert_eq "$(mf_sidecar "$CADDY_DIR/Caddyfile")" "$CADDY_DIR/.caddyfile.sha256"

it "mf_sidecar does not double the leading dot for dotfiles"
assert_eq "$(mf_sidecar "/opt/remnawave/.env")" "/opt/remnawave/.env.sha256"

it "mf_stamp writes the ownership marker as the first line"
printf 'body\n' > "$CADDY_DIR/Caddyfile"
mf_stamp "$CADDY_DIR/Caddyfile"
assert_eq "$(head -n1 "$CADDY_DIR/Caddyfile")" "# managed-by: remnawave.sh v6.8.0"

it "mf_stamp records the sha256 of the stamped file"
assert_eq "$(cat "$CADDY_DIR/.caddyfile.sha256")" "$(mf_sha256_of "$CADDY_DIR/Caddyfile")"

it "mf_is_ours accepts a freshly stamped file"
mf_is_ours "$CADDY_DIR/Caddyfile"; assert_success "$?"

it "mf_is_ours rejects a stamped file that was edited by hand"
echo "admin added a mirror" >> "$CADDY_DIR/Caddyfile"
mf_is_ours "$CADDY_DIR/Caddyfile"; assert_rc "$?" 1

it "mf_is_ours rejects a file without the marker"
printf 'hand written\n' > "$CADDY_DIR/other"
mf_is_ours "$CADDY_DIR/other"; assert_rc "$?" 1
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
it "clean install generates the file, the marker and the checksum"
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "hello" >/dev/null
assert_rc "$?" 0
it "clean install reports 'written'"
assert_eq "$MF_WRITE_RESULT" "written"
it "clean install leaves a verifiable checksum"
mf_is_ours "$CADDY_DIR/Caddyfile"; assert_success "$?"
it "clean install creates no .new- candidate"
assert_file_missing "$CADDY_DIR/Caddyfile.new-6.8.0"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
it "a generated, untouched file is regenerated when the template changes"
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "v1" >/dev/null
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "v2" >/dev/null
assert_rc "$?" 0
it "regeneration backs the previous file up"
assert_file_exists "$MF_LAST_BACKUP"
it "the regenerated file carries the new template"
assert_contains "$(cat "$CADDY_DIR/Caddyfile")" "v2"

it "an unchanged template is a no-op"
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "v2" >/dev/null
assert_rc "$?" 3
teardown_sandbox

# ---------------------------------------------------------------------------
# The regression itself: an 8-domain hand-maintained config must survive.
setup_sandbox
cp "$REPO_ROOT/tests/fixtures/user-caddyfile" "$CADDY_DIR/Caddyfile"
cp "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"

it "a user-owned Caddyfile is NOT overwritten"
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "template from the script" > "$SANDBOX/out" 2>&1
rc=$?
out=$(cat "$SANDBOX/out")
assert_rc "$rc" 2
it "the user's file stays byte-for-byte identical"
assert_files_identical "$CADDY_DIR/Caddyfile" "$SANDBOX/pristine"
it "the new template is written beside it as Caddyfile.new-<version>"
assert_file_exists "$CADDY_DIR/Caddyfile.new-6.8.0"
it "the candidate holds the new template"
assert_contains "$(cat "$CADDY_DIR/Caddyfile.new-6.8.0")" "template from the script"
it "the operator is warned that the file was kept"
assert_contains "$out" "kept"
it "a diff of the two files is printed"
assert_contains "$out" "SUB_DOMAIN_FAILBACK"
it "the result is reported as 'kept'"
assert_eq "$MF_WRITE_RESULT" "kept"
it "no ownership is claimed over a user file"
assert_file_missing "$CADDY_DIR/.caddyfile.sha256"

it "--strict records the violation so the caller can exit non-zero"
STRICT_MODE="true"
MF_STRICT_VIOLATION="false"
mf_write_guarded "$CADDY_DIR/Caddyfile" "Caddyfile" fake_generator "again" >/dev/null 2>&1
assert_eq "$MF_STRICT_VIOLATION" "true"
STRICT_MODE="false"
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
it "mf_guard_before_write refuses to touch a user-owned .env"
printf 'APP_PORT=3000\n' > "$CADDY_DIR/.env"
mf_guard_before_write "$CADDY_DIR/.env" ".env" >/dev/null 2>&1
assert_rc "$?" 1

it "mf_guard_before_write allows a missing file"
mf_guard_before_write "$CADDY_DIR/nope" ".env" >/dev/null 2>&1
assert_rc "$?" 0

it "mf_guard_before_write allows a file this script generated and owns"
mf_stamp "$CADDY_DIR/.env"
mf_guard_before_write "$CADDY_DIR/.env" ".env" >/dev/null 2>&1
assert_rc "$?" 0
teardown_sandbox

# ---------------------------------------------------------------------------
setup_sandbox
it "only the 10 newest backups are kept"
printf 'body\n' > "$CADDY_DIR/Caddyfile"
i=1
while [ "$i" -le 13 ]; do
    touch "$CADDY_DIR/Caddyfile.backup.202609$(printf '%02d' "$i")_120000"
    i=$((i + 1))
done
mf_prune_backups "$CADDY_DIR/Caddyfile"
assert_eq "$(ls -1 "$CADDY_DIR" | grep -c 'Caddyfile.backup.')" "10"

it "pruning keeps the newest, not the oldest"
assert_file_exists "$CADDY_DIR/Caddyfile.backup.20260913_120000"
it "pruning drops the oldest"
assert_file_missing "$CADDY_DIR/Caddyfile.backup.20260901_120000"

it "mf_backup names backups Caddyfile.backup.<YYYYmmdd_HHMMSS>"
b=$(mf_backup "$CADDY_DIR/Caddyfile")
case "$(basename "$b")" in
    Caddyfile.backup.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]*) pass ;;
    *) fail "unexpected backup name: $(basename "$b")" ;;
esac

it "mf_restore restores in place, keeping the inode (bind-mounted file)"
before_inode=$(ls -i "$CADDY_DIR/Caddyfile" | awk '{print $1}')
printf 'broken\n' > "$CADDY_DIR/Caddyfile"
mf_restore "$b" "$CADDY_DIR/Caddyfile"
after_inode=$(ls -i "$CADDY_DIR/Caddyfile" | awk '{print $1}')
if [ "$before_inode" = "$after_inode" ] && cmp -s "$b" "$CADDY_DIR/Caddyfile"; then pass; else fail "inode changed or content not restored"; fi
teardown_sandbox

finish_suite
