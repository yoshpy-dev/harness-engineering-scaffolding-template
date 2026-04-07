#!/usr/bin/env sh
set -eu

# Ralph Loop orchestrator
# Runs `cat PROMPT.md | claude -p` in a loop with safety rails.
# State lives in .harness/state/loop/

LOOP_DIR=".harness/state/loop"
MAX_ITERATIONS=20
QUALITY_CYCLE=1
DRY_RUN=0
ALLOWED_TOOLS=""
MAX_COST=""
PROGRESS_KEEP=10

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Runs the Ralph Loop from ${LOOP_DIR}/PROMPT.md."
  echo ""
  echo "Options:"
  echo "  --max-iterations N    Maximum iterations (default: 20)"
  echo "  --no-quality-cycle    Disable quality cycle (implement-only, legacy mode)"
  echo "  --allowed-tools LIST  Comma-separated list of allowed tools for claude -p"
  echo "  --max-cost USD        Stop when estimated cost exceeds this amount"
  echo "  --dry-run             Print what would run without executing claude"
  echo "  --progress-keep N     Keep last N iterations in progress.log (default: 10)"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --max-iterations)
      shift
      MAX_ITERATIONS="${1:?--max-iterations requires a number}"
      ;;
    --no-quality-cycle)
      QUALITY_CYCLE=0
      ;;
    --allowed-tools)
      shift
      ALLOWED_TOOLS="${1:?--allowed-tools requires a comma-separated list}"
      ;;
    --max-cost)
      shift
      MAX_COST="${1:?--max-cost requires a number}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --progress-keep)
      shift
      PROGRESS_KEEP="${1:?--progress-keep requires a number}"
      ;;
    # Legacy flag — quality cycle is now the default
    --verify)
      echo "Note: --verify is deprecated. Quality cycle (implement+review+verify+test) is now default."
      echo "Use --no-quality-cycle to disable."
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# --- Pre-flight checks ---

if [ ! -f "${LOOP_DIR}/PROMPT.md" ]; then
  echo "Error: ${LOOP_DIR}/PROMPT.md not found."
  echo "Run ./scripts/ralph-loop-init.sh first."
  exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI not found in PATH."
  exit 1
fi

mkdir -p "${LOOP_DIR}"

# Initialize or read stuck counter
stuck_count=0
if [ -f "${LOOP_DIR}/stuck.count" ]; then
  stuck_count="$(cat "${LOOP_DIR}/stuck.count")"
fi

# --- Progress log trimming ---
# Keep only the last N iterations in progress.log, archive the rest.
trim_progress_log() {
  progress_file="${LOOP_DIR}/progress.log"
  archive_file="${LOOP_DIR}/progress-archive.log"

  if [ ! -f "$progress_file" ]; then
    return
  fi

  # Count iteration headers
  # Note: grep -c exits with 1 when count is 0, so use fallback assignment
  iter_count=$(grep -c '^## Iteration ' "$progress_file" 2>/dev/null) || iter_count=0

  if [ "$iter_count" -le "$PROGRESS_KEEP" ]; then
    return
  fi

  # Number of iterations to archive
  archive_count=$((iter_count - PROGRESS_KEEP))

  # Find the line number of the (archive_count+1)th iteration header
  # That's where we split: everything before goes to archive, rest stays
  cut_line=$(grep -n '^## Iteration ' "$progress_file" | sed -n "$((archive_count + 1))p" | cut -d: -f1)

  if [ -z "$cut_line" ]; then
    return
  fi

  # Archive old entries (append to archive file)
  head -n "$((cut_line - 1))" "$progress_file" >> "$archive_file"

  # Keep header + recent entries
  header_end=$(grep -n '^## Iteration ' "$progress_file" | head -1 | cut -d: -f1)
  if [ -n "$header_end" ]; then
    # Preserve the file header (lines before first iteration)
    head -n "$((header_end - 1))" "$progress_file" > "${progress_file}.tmp"
    # Append the kept iterations
    tail -n "+${cut_line}" "$progress_file" >> "${progress_file}.tmp"
    mv "${progress_file}.tmp" "$progress_file"
  fi

  echo "Trimmed progress.log: archived ${archive_count} old iterations"
}

# --- Token cost tracking ---
extract_tokens_from_json() {
  json_file="$1"
  # Extract token usage from claude --output-format json output
  # The JSON output includes usage.input_tokens and usage.output_tokens
  if [ -f "$json_file" ]; then
    input_tokens=$(grep -o '"input_tokens":[0-9]*' "$json_file" | tail -1 | cut -d: -f2 || echo "0")
    output_tokens=$(grep -o '"output_tokens":[0-9]*' "$json_file" | tail -1 | cut -d: -f2 || echo "0")
    echo "$((${input_tokens:-0} + ${output_tokens:-0}))"
  else
    echo "0"
  fi
}

update_phase_state() {
  iteration_num="$1"
  tokens_used="$2"

  state_file="${LOOP_DIR}/phase-state.json"
  if [ ! -f "$state_file" ]; then
    return
  fi

  # Read current total
  current_total=$(grep -o '"total_tokens": *[0-9]*' "$state_file" | grep -o '[0-9]*' || echo "0")
  new_total=$((${current_total:-0} + ${tokens_used:-0}))

  # Update iteration number and total tokens
  # Use a temp file to avoid sed -i portability issues
  sed \
    -e "s/\"current_iteration\": *[0-9]*/\"current_iteration\": ${iteration_num}/" \
    -e "s/\"total_tokens\": *[0-9]*/\"total_tokens\": ${new_total}/" \
    "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
}

check_cost_limit() {
  if [ -z "$MAX_COST" ]; then
    return 0
  fi

  state_file="${LOOP_DIR}/phase-state.json"
  if [ ! -f "$state_file" ]; then
    return 0
  fi

  total_tokens=$(grep -o '"total_tokens": *[0-9]*' "$state_file" | grep -o '[0-9]*' || echo "0")
  # Rough cost estimate: $3/M input + $15/M output, average ~$9/M blended
  # Use integer math: cost_cents = total_tokens * 9 / 10000
  cost_cents=$(( ${total_tokens:-0} * 9 / 10000 ))
  max_cost_cents=$(echo "$MAX_COST" | awk '{printf "%d", $1 * 100}')

  if [ "$cost_cents" -ge "$max_cost_cents" ]; then
    echo "Cost limit reached: ~\$$(( cost_cents / 100 )).$(printf '%02d' $(( cost_cents % 100 ))) >= \$${MAX_COST}"
    return 1
  fi
  return 0
}

# Build claude command arguments
build_claude_args() {
  args="-p --output-format json"
  if [ -n "$ALLOWED_TOOLS" ]; then
    args="${args} --allowedTools ${ALLOWED_TOOLS}"
  fi
  echo "$args"
}

echo "running" > "${LOOP_DIR}/status"

iteration=0
total_tokens_session=0
start_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "=== Ralph Loop started ==="
echo "- Max iterations: ${MAX_ITERATIONS}"
echo "- Quality cycle: ${QUALITY_CYCLE}"
echo "- Allowed tools: ${ALLOWED_TOOLS:-all}"
echo "- Max cost: ${MAX_COST:-unlimited}"
echo "- Dry run: ${DRY_RUN}"
echo "- Start: ${start_ts}"
echo ""

while [ "$iteration" -lt "$MAX_ITERATIONS" ]; do
  iteration=$((iteration + 1))
  iter_padded="$(printf '%03d' "$iteration")"
  log_file="${LOOP_DIR}/iteration-${iter_padded}.log"
  json_file="${LOOP_DIR}/iteration-${iter_padded}.json"
  iter_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  echo "--- Iteration ${iteration}/${MAX_ITERATIONS} [${iter_ts}] ---"

  # Trim progress log before each iteration
  trim_progress_log

  # Check cost limit before running
  if ! check_cost_limit; then
    echo ""
    echo "=== Loop stopped: cost limit reached ==="
    echo "cost_limit" > "${LOOP_DIR}/status"
    break
  fi

  # Capture git state before iteration
  diff_before=""
  if command -v git >/dev/null 2>&1; then
    diff_before="$(git diff HEAD 2>/dev/null || true)"
  fi

  claude_args="$(build_claude_args)"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would run: cat ${LOOP_DIR}/PROMPT.md | claude ${claude_args}"
    echo "[dry-run] Quality cycle: ${QUALITY_CYCLE}"
    echo "[dry-run] Output would be saved to: ${log_file}"
    echo "[dry-run] iteration ${iteration} complete" > "$log_file"
    echo '{"usage":{"input_tokens":0,"output_tokens":0}}' > "$json_file"
  else
    # Run claude with JSON output for token tracking, tee human-readable log
    cat "${LOOP_DIR}/PROMPT.md" | claude ${claude_args} 2>&1 | tee "$log_file"
    # Copy for JSON parsing (log_file may have mixed content)
    cp "$log_file" "$json_file"
  fi

  # Extract and track token usage
  iter_tokens="$(extract_tokens_from_json "$json_file")"
  total_tokens_session=$((total_tokens_session + iter_tokens))
  update_phase_state "$iteration" "$iter_tokens"
  echo "  Tokens this iteration: ${iter_tokens}"

  # Check for completion signal
  if grep -q '<promise>COMPLETE</promise>' "$log_file" 2>/dev/null; then
    echo ""
    if [ "$QUALITY_CYCLE" -eq 1 ]; then
      echo "=== Loop complete: agent completed full quality cycle ==="
    else
      echo "=== Loop complete: agent signalled COMPLETE ==="
    fi
    echo "complete" > "${LOOP_DIR}/status"
    echo "0" > "${LOOP_DIR}/stuck.count"
    break
  fi

  # Check for abort signal
  if grep -q '<promise>ABORT</promise>' "$log_file" 2>/dev/null; then
    echo ""
    echo "=== Loop aborted: agent signalled ABORT ==="
    echo "aborted" > "${LOOP_DIR}/status"
    echo "0" > "${LOOP_DIR}/stuck.count"
    break
  fi

  # Stuck detection: compare git diff before and after
  if command -v git >/dev/null 2>&1; then
    diff_after="$(git diff HEAD 2>/dev/null || true)"
    if [ "$diff_before" = "$diff_after" ]; then
      stuck_count=$((stuck_count + 1))
      echo "Warning: no file changes detected (stuck count: ${stuck_count}/3)"
    else
      stuck_count=0
    fi
    printf '%s' "$stuck_count" > "${LOOP_DIR}/stuck.count"

    if [ "$stuck_count" -ge 3 ]; then
      echo ""
      echo "=== Loop stopped: stuck detected (3 consecutive iterations with no changes) ==="
      echo "stuck" > "${LOOP_DIR}/status"
      break
    fi
  fi
done

# Check if we hit max iterations
if [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
  current_status="$(cat "${LOOP_DIR}/status" 2>/dev/null || echo "running")"
  if [ "$current_status" = "running" ]; then
    echo ""
    echo "=== Loop stopped: max iterations (${MAX_ITERATIONS}) reached ==="
    echo "max_iterations" > "${LOOP_DIR}/status"
  fi
fi

end_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
final_status="$(cat "${LOOP_DIR}/status")"

# Read final token count from phase state
final_tokens="unknown"
if [ -f "${LOOP_DIR}/phase-state.json" ]; then
  final_tokens=$(grep -o '"total_tokens": *[0-9]*' "${LOOP_DIR}/phase-state.json" | grep -o '[0-9]*' || echo "unknown")
fi

echo ""
echo "=== Ralph Loop summary ==="
echo "- Iterations run: ${iteration}"
echo "- Final status: ${final_status}"
echo "- Quality cycle: ${QUALITY_CYCLE}"
echo "- Total tokens: ${final_tokens}"
echo "- Started: ${start_ts}"
echo "- Ended: ${end_ts}"
echo "- Logs: ${LOOP_DIR}/iteration-*.log"
