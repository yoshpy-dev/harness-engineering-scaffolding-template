#!/usr/bin/env sh
set -eu

# Initialize a Ralph Swarm session.
# Creates worktrees and loop state for each slice defined in a swarm plan.

SWARM_DIR=".harness/state/swarm"
WORKTREE_BASE=".claude/worktrees"

usage() {
  echo "Usage: $0 <plan-file>"
  echo ""
  echo "Reads slice definitions from a swarm plan and initializes"
  echo "a worktree + Ralph Loop for each slice."
  echo ""
  echo "Example:"
  echo "  $0 docs/plans/active/2026-04-07-my-feature.md"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

plan_file="$1"

if [ ! -f "$plan_file" ]; then
  echo "Error: plan file not found: ${plan_file}"
  exit 1
fi

# Archive previous swarm state if it exists
if [ -d "$SWARM_DIR" ] && [ -f "${SWARM_DIR}/swarm.json" ]; then
  archive_ts="$(date -u '+%Y%m%d-%H%M%S')"
  archive_dest=".harness/state/swarm-archive/${archive_ts}"
  mkdir -p "$archive_dest"
  cp -r "${SWARM_DIR}/." "$archive_dest/"
  echo "Archived previous swarm state to ${archive_dest}"
  rm -rf "$SWARM_DIR"
fi

mkdir -p "$SWARM_DIR"

# Parse slice table from plan file
# Expected format: | slice-name | description | files | depends-on | size | task-type |
# Skip header and separator rows
slices=""
slice_count=0

while IFS='|' read -r _ slice_name description files_owned depends_on size task_type _; do
  # Trim whitespace
  slice_name="$(echo "$slice_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  description="$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  files_owned="$(echo "$files_owned" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  depends_on="$(echo "$depends_on" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  task_type="$(echo "$task_type" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # Skip empty, header, and separator rows
  case "$slice_name" in
    ""|-*|Slice|slice) continue ;;
  esac

  slice_count=$((slice_count + 1))

  # Normalize depends_on: "(none)" or empty means no dependencies
  case "$depends_on" in
    "(none)"|"none"|""|"-") depends_on="" ;;
  esac

  # Default task type
  if [ -z "$task_type" ] || [ "$task_type" = "-" ]; then
    task_type="general"
  fi

  slices="${slices}${slice_name}:${depends_on}:${task_type}:${description}\n"

  echo "Found slice: ${slice_name} (type: ${task_type}, depends: ${depends_on:-none})"
done < <(grep '^|' "$plan_file" | grep -v '^| *Slice' | grep -v '^| *-')

if [ "$slice_count" -eq 0 ]; then
  echo "Error: no slices found in plan file."
  echo "Expected a markdown table with columns: Slice | Description | Files owned | Depends on | Size | Task type"
  exit 1
fi

echo ""
echo "Found ${slice_count} slices. Creating worktrees and loop state..."
echo ""

# Extract objective from plan file
objective="$(grep -A1 '^## Objective' "$plan_file" | tail -1 | sed 's/^[[:space:]]*//')"

# Create worktree and init loop for each slice
printf '%b' "$slices" | while IFS=: read -r slice_name depends_on task_type description; do
  [ -z "$slice_name" ] && continue

  worktree_path="${WORKTREE_BASE}/${slice_name}"
  branch_name="feat/swarm/${slice_name}"

  echo "--- Setting up slice: ${slice_name} ---"

  # Create worktree
  if [ -d "$worktree_path" ]; then
    echo "  Worktree already exists: ${worktree_path}"
  else
    git worktree add "$worktree_path" -b "$branch_name" 2>/dev/null || {
      echo "  Warning: could not create worktree for ${slice_name}"
      continue
    }
    echo "  Created worktree: ${worktree_path} (branch: ${branch_name})"
  fi

  # Initialize Ralph Loop inside the worktree
  slice_objective="${description:-${objective} — slice: ${slice_name}}"
  (
    cd "$worktree_path"
    # Extract plan slug from filename
    plan_slug="$(basename "$plan_file" .md)"
    sh ./scripts/ralph-loop-init.sh "$task_type" "$slice_objective" "$plan_slug"
  )

  echo "  Loop initialized in ${worktree_path}"
  echo ""
done

# Create swarm metadata
created_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
cat > "${SWARM_DIR}/swarm.json" <<EOF
{
  "plan": "${plan_file}",
  "created": "${created_ts}",
  "slice_count": ${slice_count},
  "status": "pending"
}
EOF

# Create slice registry with dependencies
echo "[]" > "${SWARM_DIR}/slices.json"
printf '%b' "$slices" | while IFS=: read -r slice_name depends_on task_type description; do
  [ -z "$slice_name" ] && continue
  # Append slice info (simple line-based format for shell parsing)
  echo "${slice_name}|${depends_on}|${task_type}|pending" >> "${SWARM_DIR}/slice-status.txt"
done

echo ""
echo "=== Ralph Swarm initialized ==="
echo "  Plan: ${plan_file}"
echo "  Slices: ${slice_count}"
echo "  Worktrees: ${WORKTREE_BASE}/"
echo "  State: ${SWARM_DIR}/"
echo ""
echo "Next: run ./scripts/ralph-swarm.sh to start parallel execution"
