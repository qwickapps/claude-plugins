#!/usr/bin/env bash
# test-session-start.sh — regression test for protocols#1337.
#
# session-start.sh's sop_config is a double-quoted shell string containing
# escaped quotes like \"note\" -- bash collapses \" to a bare " at assignment
# time, so interpolating that variable straight into a hand-built JSON
# literal (the original bug) ends the JSON string early at the first bare
# quote. jq rejects the result with "Expected '}'"/"Invalid string" errors.
#
# This test runs the REAL hook script and validates its REAL stdout with jq
# -- not a reimplementation of the escaping logic, which would pass or fail
# independently of whether the hook itself is actually fixed.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$DIR/session-start.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '[PASS] %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$1" >&2; }

out="$(bash "$HOOK")"

if printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
  pass "hook stdout is valid JSON"
else
  fail "hook stdout is NOT valid JSON (this is the protocols#1337 regression)"
  printf '%s\n' "$out" >&2
  printf '\nTests passed: %s\nTests failed: %s\n' "$PASS" "$FAIL"
  exit 1
fi

decoded="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"

# The specific quoted terms that broke the original hand-built JSON.
for term in '"note"' '"spike"' '"sprint-handoff"'; do
  if printf '%s' "$decoded" | grep -qF "$term"; then
    pass "decoded content preserves the quoted term $term"
  else
    fail "decoded content is missing or mangled the quoted term $term"
  fi
done

# Literal \n in the source must decode to real newlines, not survive as the
# two characters backslash-n.
if printf '%s' "$decoded" | grep -qF '\n'; then
  fail "decoded content still contains literal backslash-n (newlines not expanded)"
else
  pass "decoded content has no literal backslash-n (newlines expanded correctly)"
fi

if printf '%s' "$decoded" | head -1 | grep -qF '<IMPORTANT>'; then
  pass "decoded content starts with the expected <IMPORTANT> marker on its own line"
else
  fail "decoded content does not start with <IMPORTANT> on its own line"
fi

printf '\nTests passed: %s\n' "$PASS"
printf 'Tests failed: %s\n' "$FAIL"
[[ "$FAIL" -eq 0 ]]
