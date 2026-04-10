# Self-review report: Ralph Loop v2 — 完全自律開発パイプライン

- Date: 2026-04-09
- Plan: docs/plans/active/2026-04-09-ralph-loop-v2.md
- Reviewer: reviewer subagent (claude-sonnet-4-6)
- Scope: Diff quality only — naming, readability, null safety, debug code, secrets, exception handling, security, maintainability. Spec compliance and test coverage are excluded.

## Evidence reviewed

- `git diff main...feat/ralph-loop-v2` — 2565 insertions across 14 files
- `scripts/ralph-pipeline.sh` (769 lines, new)
- `scripts/ralph-orchestrator.sh` (575 lines, new)
- `scripts/ralph` (350 lines, new)
- `scripts/ralph-loop-init.sh` (101 lines modified)
- `.claude/skills/loop/prompts/pipeline-inner.md`, `pipeline-review.md`, `pipeline-outer.md` (new)
- `docs/plans/templates/ralph-loop-plan.md` (new)
- Updated: `loop/SKILL.md`, `plan/SKILL.md`, `subagent-policy.md`, `CLAUDE.md`, `AGENTS.md`
- Plan acceptance criteria reviewed for scope confirmation

---

## Findings

| Severity | Area | Finding | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| HIGH | null-safety | `ralph-pipeline.sh` reads `.claude/skills/loop/prompts/pipeline-inner.md` (raw template with `__OBJECTIVE__` and `__PLAN_PATH__` placeholders) instead of the substituted copy at `${PIPELINE_DIR}/pipeline-inner.md` that `ralph-loop-init.sh --pipeline` produces. When `ralph-pipeline.sh` runs after init, the agent receives literal `__OBJECTIVE__` in the prompt. | `ralph-pipeline.sh:314` copies from `.claude/skills/loop/prompts/pipeline-inner.md`; `ralph-loop-init.sh:162-169` writes substituted output to `${PIPELINE_DIR}/${tpl}` | Change `ralph-pipeline.sh:314` to prefer `${PIPELINE_DIR}/pipeline-inner.md` when it exists, falling back to the raw template only when the init script has not been run |
| HIGH | maintainability | Dependency check in `ralph-orchestrator.sh` is silently broken due to pipe subshell scope. `_deps_met=1` is set in the outer shell, but the `while IFS= read -r dep` loop runs in a subshell of the `echo "$d" \| tr ',' '\n' \| while` pipeline. Modifications to `_deps_met` inside the loop do not propagate back, so `_deps_met` is always 1 at line 483. All slices will start regardless of declared dependencies. | `ralph-orchestrator.sh:471-485`; in POSIX sh, a variable modified inside `cmd | while` is not visible after the pipeline | Rewrite to avoid the pipe-subshell: use a temp file, process substitution (`while ... done < <(...)`), or `$(...)` to set a return marker |
| HIGH | maintainability | Same pipe-subshell scope bug in `integration_merge_check`. `_conflicts=0` is set outside, but `_conflicts=$((_conflicts + 1))` runs inside `ls ... \| while`. The count is never visible after the while loop ends, so `[ "$_conflicts" -gt 0 ]` at line 363 always evaluates false. Merge conflicts are silently ignored. | `ralph-orchestrator.sh:331,343-357,363` | Replace `ls ... \| while` with a `for` loop over glob `"${ORCH_STATE}"/slice-*.status` to keep variables in the current shell |
| MEDIUM | maintainability | `.running_files` is appended when a slice starts (`ralph-orchestrator.sh:502`) but never cleaned up when a slice finishes. Over time all file entries accumulate, causing all subsequent slices with any overlapping files to be permanently deferred even after the locking slice completes. | `ralph-orchestrator.sh:458,488,502`; no removal code found | Remove a slice's files from `.running_files` when `check_slice_status` transitions it from `running` to a terminal state |
| MEDIUM | readability | `wait_for_slice` is defined at `ralph-orchestrator.sh:310` but never called. The polling loop at lines 460-525 uses `sleep 5` and `check_slice_status` to detect completion without ever calling `wait_for_slice`. The function is dead code and creates confusion about the intended completion strategy. | `grep wait_for_slice ralph-orchestrator.sh` returns only the definition | Remove `wait_for_slice` or call it from the polling loop |
| MEDIUM | maintainability | `ralph-pipeline.sh` verify phase ignores exit code with `\|\| true`. Static verification failures do not stop the pipeline or trigger a retry — only test failures do. A failing shellcheck or linter will proceed silently to the test phase. | `ralph-pipeline.sh:430,432`; compare with test phase at lines 443-448 which captures `_test_exit` | Either capture the verify exit code and treat failures as a retry signal (like tests), or add an explicit log warning that verify failures are non-blocking, so the design intent is clear |
| MEDIUM | readability | CRITICAL self-review findings are detected but explicitly not acted on (`ralph-pipeline.sh:421`: "Don't stop — let verify and test catch real issues"). This contradicts the pipeline contracts in `AGENTS.md` ("if CRITICAL findings: stop and fix before continuing") and the subagent-policy rule. The comment explains the decision but the disagreement with the repo contract is undocumented in the plan. | `ralph-pipeline.sh:417-422`; `subagent-policy.md` step execution notes | Either honour CRITICAL findings by stopping the pipeline, or document this deliberate deviation in the plan and add a code comment referencing the decision |
| MEDIUM | null-safety | In `run_inner_loop`, `ckpt_update ".phase = \"inner\" | .inner_cycle = ${_cycle}"` runs at line 304 before `ckpt_transition "$(ckpt_read 'phase' || echo 'start')" "inner"` at line 305. Because `ckpt_update` already set phase to "inner", `ckpt_read 'phase'` always returns "inner", making the "from" field in every inner-loop phase transition record incorrect (always shows "inner" → "inner" instead of the actual prior phase). | `ralph-pipeline.sh:304-305` | Swap the two lines: read the current phase first, then update it |
| MEDIUM | maintainability | `_total_iteration` is incremented twice per test-failure cycle: once at the outer `while` entry (line 665) and once inside the inner `while` on test failure (line 679). The effective iteration budget for failing loops is roughly `MAX_ITERATIONS / 2`. The behaviour is not documented and the variable name suggests a simple counter. | `ralph-pipeline.sh:664-679` | Either document the double-increment behaviour explicitly with a comment, or restructure so `_total_iteration` is incremented only in one place |
| MEDIUM | maintainability | In `cmd_abort` (`scripts/ralph:294`), `_wt_list` is modified inside `git worktree list ... \| while IFS=' ' read`, which is a pipe subshell. The accumulated list is invisible at line 299, so `_worktrees_removed` is always `"[]"` in the audit log when removing multiple worktrees. | `scripts/ralph:293-299` | Replace with a `for` loop or collect paths into a temp file |
| LOW | readability | `pipeline-review.md` instructs the review agent to run `./scripts/run-test.sh` itself, but `ralph-pipeline.sh` also runs a separate test phase (lines 437-453) as a deterministic shell step after the review agent call. Both paths write results to different logs. The roles of "agent-run test" and "orchestrator-run test" are not distinguished in any comment or README. | `pipeline-review.md:35-40`; `ralph-pipeline.sh:437-453` | Add a comment in both files clarifying that the orchestrator's shell-script test phase is the authoritative gate, and the agent's test run inside the review prompt is supplementary |
| LOW | readability | The `ckpt_transition` helper builds a JSON fragment by string concatenation (`ralph-pipeline.sh:89-93`). While current `_reason` values are all hardcoded, the function signature accepts any string. A future caller could pass a string containing `"` or `\` and produce invalid JSON silently. | `ralph-pipeline.sh:85-95` | Either restrict `_reason` to safe values via validation, or use `jq --arg` for the append operation instead of string concatenation |
| LOW | naming | `run_hook_parity` sounds like it runs hooks, but it actually runs a checklist that emulates what hooks would have done. A more accurate name would be `check_hook_parity` or `run_hook_parity_checklist`. | `ralph-pipeline.sh:132` | Rename function to `check_hook_parity` for naming consistency with `check_stuck`, `check_uncommitted`, `check_locklist_conflict` |
| LOW | readability | Session ID extraction from claude output uses a fragile grep pattern (`grep -o 'session_id=[^ ]*'`). If the claude CLI changes its output format, session resumption silently fails with no error, falling back to a fresh context without any warning log. | `ralph-pipeline.sh:367` | Add a log warning when `_new_session` is empty after cycle 1, so users can detect when session continuity is broken |

---

## Positive notes

- Defensive use of `${var:-default}` and `|| true` throughout to avoid `set -eu` failures on optional commands.
- Preflight probe design is sound: probes capabilities before running, gates on failure, writes structured JSON evidence.
- Hook parity checklist (`run_hook_parity`) is a well-reasoned mitigation for `claude -p` not executing hooks.
- `ckpt_update` / `ckpt_read` abstractions keep jq usage centralised and consistent.
- Use of `--arg` / `--argjson` in jq calls for structured data (preflight, hook parity) avoids injection.
- `HEREDOC` with single-quoted delimiters is used for checkpoint JSON initialisation — consistent with the project's git-commit-strategy rule.
- `report_event` provides structured JSONL event logging throughout the pipeline.
- SC2086 shellcheck disables are targeted and commented, not blanket.
- `_finalize` is defined before the `main` call, so POSIX sh function-definition ordering is respected.

---

## Tech debt identified

| Debt item | Impact | Why deferred | Trigger to pay down | Related plan/report |
| --- | --- | --- | --- | --- |
| Pipe-subshell variable scope bugs in `ralph-orchestrator.sh` (dependency check, integration merge check, abort worktree list) — all in POSIX sh where `cmd \| while` runs in a subshell | HIGH: dependency ordering and merge conflict detection are silently inoperative | Complexity of rewrite; pipeline v2 ships without orchestrator integration tests | When orchestrator is first exercised in real parallel execution, or when an integration test is added | docs/reports/self-review-2026-04-09-ralph-loop-v2.md |
| CRITICAL self-review findings not halting the pipeline — deliberate deviation from repo contract | MEDIUM: autonomous pipeline may continue past security or correctness issues | Plan's scope prioritises autonomy; stopping on every CRITICAL finding may be over-conservative for a new pipeline | When CRITICAL finding classes are well-understood from real runs, or when a security incident occurs | docs/reports/self-review-2026-04-09-ralph-loop-v2.md |

---

## Recommendation

- **Merge: NO** — Two HIGH findings must be fixed before this can be merged safely:
  1. `ralph-pipeline.sh` uses the raw unsubstituted template (`__OBJECTIVE__` literal) — the agent will malfunction on every run.
  2. `ralph-orchestrator.sh` dependency ordering and merge conflict detection are silently broken due to pipe-subshell scope — parallel execution will not respect declared dependencies, and merge conflicts will not be detected.

- **Follow-ups (post-fix):**
  - Address MEDIUM findings before the first real autonomous run
  - Add the tech debt entries above to `docs/tech-debt/README.md`
  - Document the CRITICAL-finding-bypass policy deviation in the plan or in a code comment
