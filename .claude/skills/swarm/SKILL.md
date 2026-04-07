---
name: swarm
description: Initialize a parallel Ralph Swarm session. Decomposes a plan into independent slices, creates Git Worktrees, and runs Ralph Loops in parallel. Each slice executes the full quality cycle (implement→review→verify→test) autonomously. Invoke when a task benefits from parallel vertical-slice execution.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, AskUserQuestion
---
Set up a Ralph Swarm for parallel autonomous execution.

## Goals

- Turn a plan with multiple independent slices into parallel Ralph Loops
- Each slice runs in its own Git Worktree with full quality cycle
- Merge results sequentially after all slices complete

## Steps

### Step 1 — Context

Read `AGENTS.md` and scan `docs/plans/active/` to understand the current project state.

### Step 2 — Plan validation

Confirm the active plan uses the swarm-plan template (has a `## Slice decomposition` section with a table). If not, help the user create one from `docs/plans/templates/swarm-plan.md`.

### Step 3 — Slice review

Display the slice table to the user. Use **AskUserQuestion** to confirm:
- Slice names and descriptions are correct
- File ownership boundaries are clear (no overlapping mutable files)
- Dependencies are accurate
- Task types are appropriate

### Step 4 — Initialize swarm

Run the init script:
```sh
./scripts/ralph-swarm-init.sh <plan-file-path>
```

### Step 5 — Verify worktrees

Confirm all worktrees were created successfully. Display the list of worktrees and their loop state.

### Step 6 — Approval

Use **AskUserQuestion** to get approval:
- Options:
  1. **実行開始** — start the swarm
  2. **調整が必要** — user provides edits
  3. **キャンセル** — abort

### Step 7 — Present run command

After approval, print the run command:
```sh
./scripts/ralph-swarm.sh                                    # basic
./scripts/ralph-swarm.sh --max-parallel 3                   # limit concurrency
./scripts/ralph-swarm.sh --max-parallel 3 --max-iterations 15  # bounded
./scripts/ralph-swarm.sh --dry-run                          # preview only
```

## Output

- Worktrees at `.claude/worktrees/<slice-name>/`
- Each worktree has `.harness/state/loop/` with PROMPT.md, task.json, etc.
- Swarm state at `.harness/state/swarm/`
- Terminal command for the user to start parallel execution

## After the swarm

When the user returns after running the swarm:
1. Read `.harness/state/swarm/status` to check outcome
2. Check each slice status in `.claude/worktrees/<slice>/.harness/state/loop/status`
3. Review merge results
4. Suggest `/review` and `/verify` on the merged result
5. Proceed to `/test` then `/pr`

## Anti-bottleneck

Pre-select recommended options based on the plan content. See the `anti-bottleneck` skill for the full checklist.
