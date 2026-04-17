#!/usr/bin/env sh
# check_mojibake.sh — PostToolUse guard against U+FFFD injection.
#
# Background:
#   Claude Code's Write/Edit/MultiEdit tools can split multi-byte characters
#   at SSE chunk boundaries, leaving U+FFFD (replacement character, UTF-8
#   bytes EF BF BD) inside the written file. This hook scans the edited
#   file and, if it finds U+FFFD that is not allowlisted, exits 2 so
#   Claude is prompted to re-read and rewrite the corrupted section.
#
#   Temporary mitigation — remove once Claude Code upstream Issue #43746
#   (and related) is fixed in a released version and we verify no
#   regressions for a week.
#
# Contract:
#   - Reads PostToolUse JSON payload from stdin.
#   - Extracts .tool_input.file_path via jq (jq is required).
#   - If jq is missing, warn to stderr, write marker, and exit 0
#     (fail-open-with-warning — we do not want to block every edit in
#     minimal environments).
#   - If the payload is malformed or has no .tool_input.file_path, exit 0
#     (quiet no-op — Claude Code payloads without that field do not
#     reference a writable file; nothing to scan).
#   - If file does not exist, is empty, or has no U+FFFD, exit 0.
#   - If the file matches a glob in .claude/hooks/mojibake-allowlist,
#     exit 0 even when U+FFFD is present.
#   - Otherwise print an actionable message to stderr and exit 2.
#
# Environment:
#   HOOK_REPO_ROOT can be set to override the repo root used for
#   allowlist lookup and relative-path matching (used by tests).

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HOOK_REPO_ROOT:-$(cd "$HOOK_DIR/../.." && pwd)}"

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  mkdir -p "$REPO_ROOT/.harness/state" 2>/dev/null || true
  : > "$REPO_ROOT/.harness/state/mojibake-jq-missing" 2>/dev/null || true
  printf 'check_mojibake.sh: jq not found; skipping U+FFFD scan (install jq to enable).\n' >&2
  exit 0
fi

file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [ -z "$file_path" ]; then
  exit 0
fi

if [ ! -f "$file_path" ]; then
  exit 0
fi

# Compute a path that is relative to the repo root so allowlist globs
# can be written portably (e.g. "tests/fixtures/**").
rel_path="$file_path"
case "$file_path" in
  "$REPO_ROOT"/*) rel_path="${file_path#"$REPO_ROOT"/}" ;;
esac

allowlist_file="$REPO_ROOT/.claude/hooks/mojibake-allowlist"
if [ -f "$allowlist_file" ]; then
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    # Skip blank lines and comments.
    case "$pattern" in
      ''|\#*) continue ;;
    esac
    # Shell case-glob matches *, ?, [ ] but not **; normalise ** to *.
    normalised="$(printf '%s' "$pattern" | sed 's#\*\*#*#g')"
    # shellcheck disable=SC2254  # intentional glob match
    case "$rel_path" in
      $normalised) exit 0 ;;
    esac
    # shellcheck disable=SC2254
    case "$file_path" in
      $normalised) exit 0 ;;
    esac
  done < "$allowlist_file"
fi

# Build the U+FFFD byte sequence at runtime so the source file itself
# contains only ASCII (prevents the hook from flagging its own source).
FFFD="$(printf '\357\277\275')"

if LC_ALL=C grep -q "$FFFD" "$file_path" 2>/dev/null; then
  printf 'check_mojibake.sh: U+FFFD detected in %s. Re-read the file and rewrite the corrupted section without the replacement character.\n' "$file_path" >&2
  exit 2
fi

exit 0
