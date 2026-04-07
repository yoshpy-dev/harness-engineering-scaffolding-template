#!/usr/bin/env sh
set -eu

# Ralph Swarm orchestrator
# Runs multiple Ralph Loops in parallel across Git Worktrees.
# Each slice executes implement→review→verify→test autonomously.

SWARM_DIR=".harness/state/swarm"
WORKTREE_BASE=".claude/worktrees"
MAX_PARALLEL=3
DRY_RUN=0
MAX_ITERATIONS=20
POLL_INTERVAL=10

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Runs Ralph Loops in parallel for each slice defined in the swarm."
  echo ""
  echo "Options:"
  echo "  --max-parallel N      Maximum concurrent loops (default: 3)"
  echo "  --max-iterations N    Per-slice max iterations (default: 20)"
  echo "  --dry-run             Print what would run without executing"
  echo "  --poll-interval N     Seconds between status checks (default: 10)"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --max-parallel)
      shift
      MAX_PARALLEL="${1:?--max-parallel requires a number}"
      ;;
    --max-iterations)
      shift
      MAX_ITERATIONS="${1:?--max-iterations requires a number}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --poll-interval)
      shift
      POLL_INTERVAL="${1:?--poll-interval requires a number}"
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

if [ ! -f "${SWARM_DIR}/swarm.json" ]; then
  echo "Error: ${SWARM_DIR}/swarm.json not found."
  echo "Run ./scripts/ralph-swarm-init.sh first."
  exit 1
fi

if [ ! -f "${SWARM_DIR}/slice-status.txt" ]; then
  echo "Error: ${SWARM_DIR}/slice-status.txt not found."
  exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI not found in PATH."
  exit 1
fi

# --- Helper functions ---

get_slice_status() {
  slice_name="$1"
  worktree_path="${WORKTREE_BASE}/${slice_name}"
  if [ -f "${worktree_path}/.harness/state/loop/status" ]; then
    cat "${worktree_path}/.harness/state/loop/status"
  else
    echo "pending"
  fi
}

is_slice_done() {
  status="$(get_slice_status "$1")"
  case "$status" in
    complete|aborted|stuck|max_iterations|cost_limit) return 0 ;;
    *) return 1 ;;
  esac
}

count_running() {
  count=0
  while IFS='|' read -r name deps type status; do
    [ -z "$name" ] && continue
    current="$(get_slice_status "$name")"
    if [ "$current" = "running" ]; then
      count=$((count + 1))
    fi
  done < "${SWARM_DIR}/slice-status.txt"
  echo "$count"
}

deps_satisfied() {
  slice_deps="$1"
  if [ -z "$slice_deps" ]; then
    return 0
  fi

  # Check each dependency (comma-separated)
  echo "$slice_deps" | tr ',' '\n' | while read -r dep; do
    dep="$(echo "$dep" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$dep" ] && continue
    dep_status="$(get_slice_status "$dep")"
    if [ "$dep_status" != "complete" ]; then
      return 1
    fi
  done
}

start_slice() {
  slice_name="$1"
  worktree_path="${WORKTREE_BASE}/${slice_name}"

  echo ">>> Starting slice: ${slice_name}"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would run: cd ${worktree_path} && ./scripts/ralph-loop.sh --max-iterations ${MAX_ITERATIONS}"
    return
  fi

  # Start ralph-loop.sh in background inside the worktree
  (
    cd "$worktree_path"
    ./scripts/ralph-loop.sh --max-iterations "$MAX_ITERATIONS" \
      > ".harness/state/loop/swarm-output.log" 2>&1
  ) &

  echo "  PID: $!"
  echo "$!" > "${SWARM_DIR}/pid-${slice_name}.txt"
}

# --- Main loop ---

start_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "=== Ralph Swarm started ==="
echo "- Max parallel: ${MAX_PARALLEL}"
echo "- Max iterations per slice: ${MAX_ITERATIONS}"
echo "- Dry run: ${DRY_RUN}"
echo "- Poll interval: ${POLL_INTERVAL}s"
echo "- Start: ${start_ts}"
echo ""

# Count total slices
total_slices=$(wc -l < "${SWARM_DIR}/slice-status.txt" | tr -d ' ')
completed_slices=0

while [ "$completed_slices" -lt "$total_slices" ]; do
  running="$(count_running)"
  completed_slices=0
  pending_slices=0

  # Check each slice
  while IFS='|' read -r name deps type status; do
    [ -z "$name" ] && continue

    current="$(get_slice_status "$name")"

    if is_slice_done "$name"; then
      completed_slices=$((completed_slices + 1))
      continue
    fi

    if [ "$current" = "running" ]; then
      continue
    fi

    # Slice is pending — check if we can start it
    if [ "$running" -lt "$MAX_PARALLEL" ] && deps_satisfied "$deps"; then
      start_slice "$name"
      running=$((running + 1))
    else
      pending_slices=$((pending_slices + 1))
    fi
  done < "${SWARM_DIR}/slice-status.txt"

  echo "[$(date -u '+%H:%M:%S')] Running: ${running}, Completed: ${completed_slices}/${total_slices}, Pending: ${pending_slices}"

  if [ "$completed_slices" -ge "$total_slices" ]; then
    break
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would poll every ${POLL_INTERVAL}s until all slices complete"
    break
  fi

  sleep "$POLL_INTERVAL"
done

# --- Sequential merge ---

echo ""
echo "=== All slices finished. Starting sequential merge... ==="
echo ""

merge_success=0
merge_fail=0

while IFS='|' read -r name deps type status; do
  [ -z "$name" ] && continue

  slice_status="$(get_slice_status "$name")"
  branch_name="feat/swarm/${name}"

  if [ "$slice_status" != "complete" ]; then
    echo "--- Skipping ${name}: status=${slice_status} ---"
    merge_fail=$((merge_fail + 1))
    continue
  fi

  echo "--- Merging ${name} (${branch_name}) ---"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would merge ${branch_name} into current branch"
    merge_success=$((merge_success + 1))
    continue
  fi

  if git merge "$branch_name" --no-edit 2>/dev/null; then
    echo "  Merged successfully"
    merge_success=$((merge_success + 1))
  else
    echo "  CONFLICT: merge failed for ${name}. Aborting this merge."
    git merge --abort 2>/dev/null || true
    merge_fail=$((merge_fail + 1))
    echo "  Resolve manually: git merge ${branch_name}"
  fi
done < "${SWARM_DIR}/slice-status.txt"

end_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo ""
echo "=== Ralph Swarm summary ==="
echo "- Total slices: ${total_slices}"
echo "- Merged: ${merge_success}"
echo "- Failed/skipped: ${merge_fail}"
echo "- Started: ${start_ts}"
echo "- Ended: ${end_ts}"

if [ "$merge_fail" -gt 0 ]; then
  echo ""
  echo "Some slices failed or had merge conflicts."
  echo "Review individual slice logs in ${WORKTREE_BASE}/<slice>/.harness/state/loop/"
fi

# Update swarm status
if [ "$merge_fail" -eq 0 ]; then
  echo "complete" > "${SWARM_DIR}/status"
else
  echo "partial" > "${SWARM_DIR}/status"
fi
