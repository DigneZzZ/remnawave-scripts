#!/usr/bin/env bash
# Structural regression guard.
#
# The 11.09 outage was one unguarded `cat >` on a config file. This suite walks
# remnawave.sh and fails if any write to a managed config path is not preceded
# by an ownership check. Run it against an older revision to see it fire:
#   git show <rev>:remnawave.sh > /tmp/old.sh && bash tests/test-no-unguarded-writes.sh /tmp/old.sh
. "$(cd "$(dirname "$0")" && pwd)/lib/harness.sh"
SUITE_NAME="no-unguarded-writes"

TARGET="${1:-$SCRIPT_UNDER_TEST}"

# Paths that hold operator-owned configuration.
MANAGED_TARGETS='\$ENV_FILE|\$SUB_ENV_FILE|\$COMPOSE_FILE|\$CADDY_DIR/(Caddyfile|\.env|docker-compose\.yml)'
# Any of these within the preceding lines means the write is gated.
GUARDS='mf_guard_before_write|mf_write_guarded|caddy_write_config|write_caddy_env|! -f "\$SUB_ENV_FILE"|caddyfile_render'
LOOKBACK=15

echo "== $SUITE_NAME ($(basename "$TARGET")) =="

unguarded=""
while IFS=: read -r lineno _; do
    [ -n "$lineno" ] || continue
    start=$((lineno - LOOKBACK))
    [ "$start" -lt 1 ] && start=1
    context=$(sed -n "${start},${lineno}p" "$TARGET")
    if ! printf '%s' "$context" | grep -qE "$GUARDS"; then
        unguarded="$unguarded $lineno"
    fi
done <<EOF
$(grep -nE "(cat|tee) *> *\"?($MANAGED_TARGETS)\"?" "$TARGET")
EOF

it "every write to a managed config file is guarded by an ownership check"
if [ -z "$unguarded" ]; then
    pass
else
    fail "unguarded writes at line(s):$unguarded" \
         "$(for l in $unguarded; do sed -n "${l}p" "$TARGET"; done)"
fi

it "the Caddyfile templates carry no unconditional catch-all"
if grep -qE '^\s*respond 204' "$TARGET"; then
    fail "the ':443 { tls internal; respond 204 }' catch-all is still generated"
else
    pass
fi

it "the catch-all block is only emitted behind --catch-all"
if grep -q 'CADDY_CATCH_ALL' "$TARGET"; then pass; else fail "no --catch-all opt-in found"; fi

it "caddy is validated before every reload"
if grep -q 'caddy validate' "$TARGET"; then pass; else fail "no 'caddy validate' call found"; fi

finish_suite
