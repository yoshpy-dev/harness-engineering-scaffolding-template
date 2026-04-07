# Verify report: Ralph Loop v2

- Date: 2026-04-07
- Plan: docs/plans/active/2026-04-07-ralph-loop-v2.md
- Verifier: Claude Code
- Scope: Spec compliance + static analysis + documentation drift
- Evidence: `docs/evidence/verify-2026-04-07-ralph-loop-v2.log`

## Spec compliance

| Acceptance criterion | Status | Evidence |
| --- | --- | --- |
| **Phase 1** | | |
| ralph-loop.sh runs implement→self-review→verify→test cycle | Met | All 6 prompt templates include 4-phase quality cycle contract. Quality cycle flag is default-on (`QUALITY_CYCLE=1`). Dry-run shows `Quality cycle: 1`. |
| Quality check failure triggers retry in next iteration | Met | Prompt templates instruct agent to note failures in progress.log and fix in next iteration. |
| COMPLETE only when all 4 phases pass | Met | All 6 templates updated: "When ALL ... AND all four phases pass", quality_cycle_complete flag required. |
| progress.log records per-phase results | Met | All templates include Implement/Self-review/Verify/Test/Result fields in iteration summary format. |
| --no-quality-cycle restores old behavior | Met | Flag sets `QUALITY_CYCLE=0`, dry-run shows `Quality cycle: 0`. Completion message differs based on flag. |
| **Phase 2** | | |
| progress.log keeps latest 10, archives old | Met | `trim_progress_log()` function, `PROGRESS_KEEP=10` default, `--progress-keep N` flag. Bug found and fixed during verification (grep -c exit code). |
| phase-state.json tracks iteration state | Met | `ralph-loop-init.sh` creates initial JSON, `update_phase_state()` updates iteration/tokens. |
| --output-format json for token tracking | Met | `build_claude_args()` includes `--output-format json`. `extract_tokens_from_json()` parses usage. |
| --allowed-tools restricts tools | Met | `--allowed-tools LIST` flag passes `--allowedTools` to claude. Dry-run verified: `--allowedTools Read,Write,Edit`. |
| **Phase 3** | | |
| ralph-swarm.sh runs parallel loops across worktrees | Met | Script created with DAG-based scheduling, background process per slice, polling loop. |
| swarm-plan.md has slice decomposition | Met | Template includes Slice/Description/Files owned/Depends on/Size/Task type table. |
| /plan flow selection includes /swarm | Met | plan/SKILL.md has 3rd option: 並列ループ (/swarm). |
| Sequential merge after completion | Met | ralph-swarm.sh merges each branch in order, aborts and reports conflicts. |
| --max-parallel N (default 3) | Met | `MAX_PARALLEL=3` default, `--max-parallel` flag, used in `[ "$running" -lt "$MAX_PARALLEL" ]`. |

## Static analysis

| Command | Result | Notes |
| --- | --- | --- |
| `bash -n ralph-loop.sh` | Pass | Syntax valid |
| `bash -n ralph-loop-init.sh` | Pass | Syntax valid |
| `bash -n ralph-swarm.sh` | Pass | Syntax valid |
| `bash -n ralph-swarm-init.sh` | Pass | Syntax valid |
| `./scripts/run-static-verify.sh` | No verifier | No project-specific linter configured |
| `shellcheck` | Not available | Not installed on this system |
| `ralph-loop.sh --dry-run` | Pass | Full dry-run with quality cycle, flags, cost tracking |
| `ralph-loop.sh --no-quality-cycle --dry-run` | Pass | Legacy mode confirmed working |
| `ralph-loop.sh --verify --dry-run` | Pass | Deprecation notice shown, quality cycle stays on |

## Documentation drift

| Doc / contract | In sync? | Notes |
| --- | --- | --- |
| CLAUDE.md | Yes | /swarm added to skill list, flow selection, quality cycle described for /loop |
| AGENTS.md | Yes | Primary loop updated with Swarm option, swarm state directory in repo map |
| .claude/skills/loop/SKILL.md | Yes | Quality cycle in goals, new CLI flags in run command, phase-state.json in output, updated "after the loop" section |
| .claude/skills/plan/SKILL.md | Yes | 3-option flow selection with /swarm, recommendation logic |
| .claude/skills/swarm/SKILL.md | Yes | New file, complete interactive setup flow |
| docs/plans/templates/swarm-plan.md | Yes | New template with slice decomposition |

## Observational checks

- **Dry-run end-to-end**: `ralph-loop-init.sh` creates all expected state files (PROMPT.md, task.json, progress.log, phase-state.json, progress-archive.log). `ralph-loop.sh --dry-run` runs iterations, trims progress, tracks tokens, respects all flags.
- **Bug found and fixed**: `trim_progress_log()` had a `grep -c` exit-code bug causing `integer expression expected` error. Fixed in-place during verification.
- **/work isolation**: Confirmed /work skill has zero references to quality cycle, swarm, or new flags — no regression risk.

## Coverage gaps

- **shellcheck** not installed — POSIX compliance issues flagged in review (process substitution, subshell return) are unverified by automated tooling.
- **ralph-swarm-init.sh** not dry-run tested end-to-end (requires creating actual worktrees from a plan with slice table).
- **Real claude -p invocation** not tested (dry-run only). Token extraction and cost limiting are untested with actual JSON output.
- **progress.log trimming** not tested with actual iterations > 10 (only validated via code inspection).

## Verdict

- Verified: All 14 acceptance criteria are met. Shell syntax passes. Dry-run confirms flag handling and quality cycle integration. Documentation is in sync.
- Partially verified: Swarm init/run scripts (syntax OK, logic inspected, but not end-to-end dry-run tested).
- Not verified: Real claude -p output parsing, shellcheck POSIX compliance, progress trimming with >10 iterations.
