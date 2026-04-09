# Verify Report — 2026-04-09-ralph-loop-v2

- Plan: `docs/plans/active/2026-04-09-ralph-loop-v2.md`
- Date: 2026-04-09
- Verifier: verifier subagent (inline fallback — subagent execution not available in this context)
- Raw log: `docs/evidence/verify-2026-04-09-ralph-loop-v2.log`

## Verdict: PARTIAL PASS

Static analysis and documentation drift checks pass. All targeted spec compliance checks
that are verifiable without a live `claude` CLI environment pass. The acceptance criteria
that require runtime execution (AC1–AC6, AC8–AC9, AC14) cannot be fully verified without
running the pipeline — those remain in "likely but unverified" status.

---

## 1. Spec compliance

### AC0: Preflight probe (`--preflight` + `docs/evidence/preflight-probe.json`)

**Status: VERIFIED (code path)**

Evidence:
- `scripts/ralph-pipeline.sh` defines `PREFLIGHT_ONLY=0` (line 19) and `--preflight` flag (line 47)
- `run_preflight()` function at line 212 writes to `${EVIDENCE_DIR}/preflight-probe.json`
  where `EVIDENCE_DIR="docs/evidence"` — path matches plan spec exactly
- Probe checks: claude CLI, jq, CLAUDE.md readable, git, codex (optional)
- On failure, sets `_all_pass=false` and calls `return 1` which causes `main()` to `exit 1` — pipeline blocked
- `main()` runs `run_preflight` before any work starts (line 614)

Gap: `preflight-probe.json` does not exist yet — it is a runtime artifact. The code path
is correct but actual probe execution is unverified without a live `claude` CLI.

---

### AC1: Inner Loop autonomous iteration + phase transition to Outer Loop

**Status: LIKELY but unverified (runtime)**

Evidence:
- `run_inner_loop()` exists and includes implement, self-review, verify, and test phases (lines 300–483)
- `run_outer_loop()` exists and transitions on `ckpt_update ".phase = \"outer\""` (line 493)
- `ckpt_transition "inner" "outer" "tests passed"` called in `run_outer_loop` (line 493)
- Main loop at line 664 iterates up to `MAX_ITERATIONS`
- Phase transition is recorded in `phase_transitions` array in `checkpoint.json`
- `docs/reports/pipeline-execution-*.json` is written by `_finalize()` at line 748

Gap: Cannot verify actual `phase` field transitions without running the pipeline.

---

### AC2: Outer Loop ACTION_REQUIRED → Inner Loop regression

**Status: LIKELY but unverified (runtime)**

Evidence:
- `run_outer_loop()` returns `1` when `_action_required -gt 0` (line 556–558)
- Main loop handles return code 1 from outer loop: increments `_inner_cycle`, sets `_context`
  to `"codex ACTION_REQUIRED — regressed from Outer Loop"`, calls `ckpt_transition "outer" "inner" "codex ACTION_REQUIRED"` (lines 729–732)
- `outer_cycle` in checkpoint.json increments correctly

Gap: Codex CLI required for actual `_action_required` count. Verified logic only.

---

### AC3: DISMISSED → automatic PR creation

**Status: LIKELY but unverified (runtime)**

Evidence:
- `run_outer_loop()` returns 0 when `_action_required == 0` (line 556)
- PR creation phase at lines 565–594 calls `run_claude` with a PR prompt
- PR URL extracted and stored in `checkpoint.json` as `pr_url` and `pr_created: true` (line 587)
- `_finalize()` records `pr_created` and `pr_url` in the execution report

Gap: Requires live `claude` CLI and `gh` CLI.

---

### AC4: `claude -p` skill operation via CLAUDE.md/rules context

**Status: LIKELY but unverified (runtime)**

Evidence:
- Preflight probe 3 ("CLAUDE.md readable") tests this directly (lines 242–257)
- Prompt templates reference CLAUDE.md-loaded rules implicitly
- `run_claude` calls `claude -p --output-format text` (line 116)

Gap: AC0 preflight must pass first. Not runtime-verified.

---

### AC5: `--continue` session continuity

**Status: LIKELY but unverified (runtime)**

Evidence:
- `_impl_extra="--resume ${_session_id}"` used when `_cycle > 1` and session_id exists (lines 360–362)
- `session_id` stored in checkpoint.json
- Preflight does not probe `--continue`/`--resume` directly — probe 3 only tests CLAUDE.md
  readability, not session continuation. **This is a gap vs AC5 spec.**

Gap: Preflight does not explicitly test `--continue` continuity. AC5 evidence requirement
(preflight probe for session continuation) is not fully met by current probe design.

---

### AC6: `checkpoint.json` schema — structure and required fields

**Status: VERIFIED**

Evidence:
- Initial `checkpoint.json` written at lines 630–652 contains all plan-required fields:
  `schema_version`, `iteration`, `phase`, `status`, `inner_cycle`, `outer_cycle`,
  `last_test_result`, `test_failures`, `failure_triage`, `review_findings`, `codex_triage`,
  `acceptance_criteria_met`, `acceptance_criteria_remaining`, `session_id`, `phase_transitions`
- Implementation adds three extra fields: `stuck_count`, `pr_created`, `pr_url`
  (these are additive, not conflicting)
- `ckpt_update` uses `jq` for atomic updates
- `jq -n ... > file` writes valid JSON; `jq "$filter" file > tmp && mv tmp file` is safe

Schema is fully compliant with plan definition. Extra fields are justified:
`pr_created` and `pr_url` support AC3; `stuck_count` supports AC10 stuck detection.

---

### AC7: `docs/plans/templates/ralph-loop-plan.md` — slice definitions + shared-file locklist

**Status: VERIFIED**

Evidence:
- `docs/plans/templates/ralph-loop-plan.md` exists (13 Apr 09, 2026)
- Contains `## Vertical slices` section (line 30)
- Contains `### Shared-file locklist` section (lines 35–46) with explanation and default entries
  (`CLAUDE.md`, `AGENTS.md`)
- Contains `### Slice 1: __SLICE_NAME__` and `### Slice 2: __SLICE_NAME__` definitions
  (lines 47–59) with `- Acceptance criteria`, `- Affected files`, `- Dependencies` fields
- Contains `## Slice dependency graph` section with ASCII diagram (lines 61–69)
- Contains progress checklist including slice-specific steps (lines 93–105)

Both required sections (slice definitions, shared-file locklist) are present.

---

### AC8: `ralph-orchestrator.sh` — multiple worktrees, parallel execution

**Status: LIKELY but unverified (runtime)**

Evidence:
- `ralph-orchestrator.sh` exists (18k, 576 lines)
- `create_worktree()` at line 203 runs `git worktree add` per slice
- `run_slice()` at line 240 runs `ralph-pipeline.sh` in a subshell with `&` (background)
- Slice PIDs written to `${ORCH_STATE}/slice-${_slug}.pid`
- `MAX_PARALLEL` cap enforced in main scheduling loop (line 496)
- Worktree path: `.claude/worktrees/<slice-slug>` — matches AC8 spec

Gap: Actual `.claude/worktrees/<slice-slug>` directories do not exist yet (runtime).

---

### AC9: Each slice completes full Inner → Outer → PR

**Status: LIKELY but unverified (runtime)**

Evidence:
- Each slice runs `ralph-pipeline.sh` which handles full Inner/Outer Loop
- `check_slice_status()` reads slice `checkpoint.json` for `status == "complete"` (line 296)

Gap: Requires end-to-end execution. No `pipeline-execution-*.json` files exist yet.

---

### AC10: Stuck detection / max iterations / ABORT / repair_limit

**Status: VERIFIED (code paths)**

Evidence:
- **Stuck detection**: `check_stuck()` at line 181 counts consecutive iterations with no git diff change; at 3 consecutive, returns 0 → `_finalize "stuck"` (line 689). Status set to `"stuck"`.
- **Max iterations**: Main loop condition `[ "$_total_iteration" -lt "$MAX_ITERATIONS" ]` (line 664). On exhaustion: `_finalize "max_iterations"` (line 739). Status set to `"max_iterations"`.
- **ABORT signal**: `grep -q '<promise>ABORT</promise>'` (line 380) → `ckpt_update '.status = "aborted"'` → `_finalize "aborted"` (line 684).
- **Repair limit**: `_total_repairs -ge $MAX_REPAIR_ATTEMPTS` (line 466) → `ckpt_update '.status = "repair_limit"'` → returns 4 → `_finalize "repair_limit"` (line 694).

Note: Implementation also produces `max_inner_cycles` and `max_outer_cycles` status values
(lines 708, 716) which are not listed in AC10's evidence spec. This is an additive extension,
not a contradiction. The four required status values are all present.

All four required status values are reachable through distinct code paths.

---

### AC11: `/work` flow unchanged

**Status: VERIFIED**

Evidence:
- `git diff main -- scripts/ralph-loop.sh`: 0 lines changed
- `git diff main -- .claude/skills/work/SKILL.md`: 0 lines changed
- `work/SKILL.md` not in diff output from `git diff main --name-only`

The `/work` flow files are completely unchanged.

---

### AC12: `./scripts/run-verify.sh` passes

**Status: VERIFIED**

Evidence:
- `./scripts/run-verify.sh` exit code: 0
- Output: "No language verifier ran. This appears to be docs or scaffold-level work only."
- This is correct because changed files fall under `.claude/`, `docs/`, `AGENTS.md`, `CLAUDE.md`,
  and `scripts/` (no language packs involved)
- Evidence file: `docs/evidence/verify-2026-04-09-080839.log`

---

### AC13: Hook parity checks

**Status: VERIFIED (code path)**

Evidence:
- `run_hook_parity()` at line 132 implements three checks:
  1. Secret leak detection: runs `commit-msg-guard.sh` on last commit message (line 139–147)
  2. Uncommitted changes: calls `check_uncommitted()` → warns if dirty (line 152–155)
  3. Forbidden file patterns: checks staged files for `.env`, `credentials.json`, `.pem` (lines 158–165)
- Results written to `docs/evidence/hook-parity-checklist.json` (line 133)
- Called after each successful Inner Loop test pass (line 480)
- JSON output uses `jq -n` for valid JSON (lines 169–170)

Gap: `hook-parity-checklist.json` does not exist yet — runtime artifact. The three parity
checks do not cover all hooks equally:
- `post_edit_verify.sh` equivalence: delegated to verify phase — REASONABLE
- `precompact_checkpoint.sh` equivalence: delegated to checkpoint.json — REASONABLE
- `pre_bash_guard.sh` forbidden command detection: only checks file patterns, not command
  patterns. This is partial coverage but noted in the plan as an accepted gap.

---

### AC14: Failure triage in `checkpoint.json`

**Status: PARTIALLY VERIFIED (structure only)**

Evidence:
- `failure_triage` array initialized in checkpoint.json (line 646)
- On test failure, `ckpt_update ".failure_triage += [{...}]"` adds an entry with:
  `failure_id`, `cycle`, `attempt`, `max_attempts`, `resolved`, `timestamp` (lines 462–463)
- Plan schema requires: `failure_id`, `test_name`, `hypothesis`, `planned_fix`,
  `expected_evidence`, `attempt`, `max_attempts`

**Gap found**: The triage entry written in `run_inner_loop()` (line 462) does NOT include
`test_name`, `hypothesis`, `planned_fix`, or `expected_evidence`. These fields are specified
in the plan's schema example but are absent from the implementation's triage entry.
The implementation records `cycle` instead. The structural schema is incomplete relative
to the plan specification for AC14.

Severity: MEDIUM — the array exists and is populated, but the schema is missing 4 fields
that AC14 requires for failure analysis. The prompt template (`pipeline-inner.md`) instructs
the agent to document hypotheses, but the orchestrator does not inject these into the
triage entry programmatically.

---

### AC15: `ralph abort` produces `docs/evidence/abort-audit-*.json`

**Status: VERIFIED (code path)**

Evidence:
- `cmd_abort()` in `scripts/ralph` at line 197
- `_audit_file="${EVIDENCE_DIR}/abort-audit-$(ts_file).json"` (line 212) where
  `EVIDENCE_DIR="docs/evidence"` — path matches plan spec exactly
- Audit log written using heredoc (lines 310–321) containing:
  `timestamp`, `reason`, `target_slice`, `killed_pids`, `archived_state`,
  `worktrees_removed`, `keep_state`, `checkpoint_at_abort`
- State archived to `.harness/state/loop-archive/<timestamp>/` (lines 262–280)
- Worktrees removed via `git worktree remove --force` (lines 283–306)
- Audit log path confirmed by `log "Audit log written to: ${_audit_file}"` (line 323)

Gap: Runtime artifact — actual execution not tested.

---

## 2. Static analysis

| Check | Result |
|-------|--------|
| `./scripts/run-verify.sh` | PASS (exit 0) |
| `bash -n scripts/ralph-pipeline.sh` | PASS |
| `bash -n scripts/ralph-orchestrator.sh` | PASS |
| `bash -n scripts/ralph` | PASS |
| `shellcheck` | SKIPPED (not installed) |

shellcheck is not installed on this machine. The plan's verify plan explicitly lists
`shellcheck` as a required static analysis check. This is an unresolved gap.

---

## 3. Documentation drift

| Document | Drift status |
|----------|-------------|
| `CLAUDE.md` | UP TO DATE — mentions pipeline mode, `ralph-pipeline.sh`, `./scripts/ralph` commands |
| `AGENTS.md` | UP TO DATE — Primary loop updated with "(pipeline-internal)" variants, repo map updated to mention `ralph` CLI, `ralph-pipeline.sh`, `ralph-orchestrator.sh` |
| `subagent-policy.md` | UP TO DATE — New sections for "Ralph Pipeline mode — self-contained" and "Ralph Orchestrator mode — parallel pipelines" match behavior |
| `loop/SKILL.md` | UP TO DATE — Full pipeline mode documented with mode selection, init commands, run commands, and post-run handling |
| `plan/SKILL.md` | UP TO DATE — References `ralph-loop-plan.md` template for parallel slice plans |
| `scripts/ralph-loop.sh` | UNCHANGED — Correct per non-goals |
| `work/SKILL.md` | UNCHANGED — Correct per non-goals |

No documentation drift detected.

---

## 4. Summary

| AC | Status |
|----|--------|
| AC0 | VERIFIED (code path); runtime probe unexecuted |
| AC1 | LIKELY — runtime |
| AC2 | LIKELY — runtime |
| AC3 | LIKELY — runtime |
| AC4 | LIKELY — runtime |
| AC5 | PARTIAL — preflight does not test `--continue` directly |
| AC6 | VERIFIED |
| AC7 | VERIFIED |
| AC8 | LIKELY — runtime |
| AC9 | LIKELY — runtime |
| AC10 | VERIFIED (code paths) |
| AC11 | VERIFIED |
| AC12 | VERIFIED |
| AC13 | VERIFIED (code path); 3/5 hooks covered directly |
| AC14 | PARTIAL — triage entry missing `test_name`, `hypothesis`, `planned_fix`, `expected_evidence` |
| AC15 | VERIFIED (code path); runtime unexecuted |

---

## 5. Issues found

### MEDIUM — AC14 failure triage schema incomplete

The `failure_triage` entry written by `run_inner_loop()` (line 462, `scripts/ralph-pipeline.sh`)
is missing four fields required by the plan's schema: `test_name`, `hypothesis`, `planned_fix`,
`expected_evidence`. The entry only records `failure_id`, `cycle`, `attempt`, `max_attempts`,
`resolved`, `timestamp`.

The plan's AC14 requirement states: "「仮説→修正→期待証拠」の failure triage が `checkpoint.json`
に記録される". The orchestrator does not capture these from the claude agent's output.

Recommendation: Either add placeholder fields (`""`) to preserve schema shape, or parse the
implementation agent's log output to extract hypothesis/fix details.

### LOW — AC5 `--continue` probe gap

The preflight probe (AC0) tests CLAUDE.md readability but does not test `--continue`/`--resume`
session continuation as required by AC5. The plan states: "AC0 の preflight probe でセッション
継続テストが pass". This probe is missing.

### INFO — shellcheck not installed

The verify plan requires shellcheck for new shell scripts. Not installed on this machine.
A CI check or local install of shellcheck would eliminate this blind spot.

### INFO — `max_inner_cycles` and `max_outer_cycles` status values are additive

The implementation produces two status values (`max_inner_cycles`, `max_outer_cycles`) not
listed in AC10's evidence spec. These are safe extensions that increase observability.

---

## 6. What remains unverified

- End-to-end pipeline execution (AC1–AC5, AC8, AC9, AC14)
- Actual `docs/evidence/preflight-probe.json` generation
- Actual `docs/evidence/hook-parity-checklist.json` generation
- Actual `docs/evidence/abort-audit-*.json` generation
- Actual `docs/reports/pipeline-execution-*.json` generation
- `--continue`/`--resume` session continuity behavior
- Codex-triggered Inner Loop regression (AC2)
- shellcheck clean run on new scripts

---

## 7. Minimal additional check that would increase confidence most

Install shellcheck and run:

```sh
shellcheck scripts/ralph-pipeline.sh scripts/ralph-orchestrator.sh scripts/ralph scripts/ralph-loop-init.sh
```

This is a pure static check that requires no live infrastructure and directly satisfies the
verify plan's stated requirement. It would close the largest static analysis gap without
requiring runtime execution.

Second highest value: fix the AC14 triage schema to include the four missing fields, then
confirm with a dry-run that `checkpoint.json` contains a well-formed `failure_triage` entry.

---

## 8. Merge recommendation

CONDITIONAL PASS — safe to merge with two known issues tracked:

1. AC14 failure triage schema is missing 4 fields (MEDIUM) — functional but incomplete
2. AC5 preflight does not probe `--continue` (LOW) — documented gap
3. shellcheck not verified (INFO) — install and run before final merge if possible

None of the issues are CRITICAL or HIGH severity. The core pipeline structure, safety stops,
documentation sync, and /work flow isolation all verify correctly.
