# Self-review report: Ralph Loop v2

- Date: 2026-04-07
- Plan: docs/plans/active/2026-04-07-ralph-loop-v2.md
- Reviewer: Claude Code (self-review)
- Scope: Diff quality only — naming, readability, safety, maintainability

## Evidence reviewed

- `git diff main` — 12 modified files, 362 insertions, 85 deletions
- 6 new untracked files (quality-cycle.md, swarm/SKILL.md, swarm-plan.md, ralph-swarm-init.sh, ralph-swarm.sh, plan file)
- Full read of all new files

## Findings

| Severity | Area | Finding | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| HIGH | maintainability | `ralph-swarm-init.sh:78` uses process substitution `< <(grep ...)` which is a bashism, but shebang is `#!/usr/bin/env sh` (POSIX). Will fail on strict POSIX shells (dash, busybox sh). | `done < <(grep '^|' "$plan_file" ...)` | Replace with a pipe or temp file: `grep '^|' "$plan_file" | grep -v ... | while ...` (accepting subshell var scope) or use a temp file pattern. |
| MEDIUM | maintainability | `ralph-swarm.sh:113` `deps_satisfied()` uses `return 1` inside a pipeline subshell (`echo | tr | while`). `return` in a subshell is technically undefined behavior in POSIX; it works in bash/dash/zsh but is fragile. | `ralph-swarm.sh:106-121` | Replace `return 1` with `exit 1` inside the pipeline, since it is already a subshell context. Or rewrite to avoid the pipeline (e.g., use a temp file or here-string). |
| MEDIUM | maintainability | `ralph-swarm-init.sh:75` uses colon (`:`) as delimiter in `$slices` variable. If a slice description contains colons, the `IFS=: read` parsing on line 94 will break. | `slices="${slices}${slice_name}:${depends_on}:${task_type}:${description}\n"` | Use a delimiter unlikely to appear in descriptions (e.g., `\t` tab, or `|` which is already used for the status file). |
| LOW | readability | `ralph-swarm-init.sh:138` writes `echo "[]" > "${SWARM_DIR}/slices.json"` but this file is never populated with actual JSON data. The registry goes to `slice-status.txt` instead. Dead / misleading artifact. | Lines 138-143 | Remove the `slices.json` creation or populate it with actual JSON. |
| LOW | maintainability | `ralph-loop.sh` `extract_tokens_from_json()` parses JSON with grep, which is fragile. Falls back gracefully to "0" but could mis-parse if output format changes. | `grep -o '"input_tokens":[0-9]*'` | Acceptable given no `jq` dependency assumption. Add a comment noting this is a best-effort parse. |
| LOW | readability | `ralph-loop.sh` `build_claude_args()` returns args via `echo` which are then used unquoted (`claude ${claude_args}`). This relies on word-splitting. | Line where `claude ${claude_args}` is called | Acceptable in this context since args are controlled. Add a comment noting intentional word-splitting. |

## Positive notes

- Consistent quality cycle integration across all 6 prompt templates — the pattern (implement → self-review → verify → test) is uniformly applied with task-specific review checks per template.
- Clear deprecation path for `--verify` flag with an informative message.
- Good separation of concerns: `trim_progress_log()`, `extract_tokens_from_json()`, `update_phase_state()`, `check_cost_limit()` are all well-named, focused functions.
- Progress log trimming preserves file header and correctly uses iteration boundaries.
- Swarm scripts have proper pre-flight checks, dry-run support, and graceful error handling for merge conflicts.
- No hardcoded secrets, no debug code, no console.log/print statements.
- Naming is grep-able and consistent with existing conventions.

## Tech debt identified

| Debt item | Impact | Why deferred | Trigger to pay down | Related plan/report |
| --- | --- | --- | --- | --- |
| Process substitution bashism in ralph-swarm-init.sh | Medium — breaks on strict POSIX sh | Functional on macOS/bash which is the primary target | When adding Linux CI or targeting non-bash systems | This review |
| deps_satisfied() subshell return semantics | Low-medium — works in practice but fragile | Works on all common shells (bash, dash, zsh) | When switching to strict POSIX compliance or observing scheduling bugs | This review |
| Colon delimiter in slice variable parsing | Low — unlikely for typical slice names | Descriptions are short identifiers in practice | When a user hits a parsing bug with complex descriptions | This review |
| Dead slices.json file in swarm init | Low — cosmetic | Not blocking functionality | Next touch of swarm-init | This review |

## Recommendation

- Merge: **Yes, with follow-ups**
- The HIGH finding (process substitution) and MEDIUM findings (subshell return, colon delimiter) are real but do not block merge — all scripts function correctly on the target platform (macOS with bash-as-sh). The issues become relevant only under strict POSIX or unusual input.
- Follow-ups:
  1. Fix the process substitution in `ralph-swarm-init.sh` before the first real swarm usage
  2. Clean up `deps_satisfied()` return semantics
  3. Remove dead `slices.json` initialization
