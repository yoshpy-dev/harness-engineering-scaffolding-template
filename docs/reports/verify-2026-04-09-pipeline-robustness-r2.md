# Verify report: Pipeline robustness improvements (r2 re-run)

- Date: 2026-04-09
- Plan: `docs/plans/active/2026-04-09-pipeline-robustness.md`
- Verifier: verifier subagent (claude-sonnet-4-6)
- Scope: Re-run after Codex WORTH_CONSIDERING fix-pass (commits `6e49d6a`, `d607cdd`). Focus areas: Inner Loop COMPLETE gating (return 6), `pipeline-outer.md` scope restriction, jq `--arg` for `report_event`, dry-run COMPLETE simulation, `sh -n` all scripts, doc drift.
- Prior report: `docs/reports/verify-2026-04-09-pipeline-robustness.md` (r1)
- Evidence: `docs/evidence/verify-2026-04-09-pipeline-robustness-r2.log`

---

## Spec compliance

All 11 ACs from r1 remain satisfied. The r2 changes do not regress any previously verified criterion. The four focused changes are verified below.

| Acceptance criterion | Status | Evidence |
|---|---|---|
| AC1: `run_claude()` uses `--output-format json`, saves JSON, extracts `.result` via jq, raw fallback on parse failure | PASS (unchanged from r1) | Lines 118–138. Unchanged by r2 commits. |
| AC2: Session ID extracted via `jq -r '.session_id // empty'`, no grep fallback | PASS (unchanged from r1) | Lines 421–428. Unchanged by r2 commits. |
| AC3: COMPLETE and ABORT 2-layer detection (sidecar + marker grep) | PASS (unchanged from r1) | Lines 436–463. Unchanged by r2 commits. |
| AC4: Sidecar files cleared at each Inner Loop cycle start | PASS (unchanged from r1) | Line 354: `rm -f "${PIPELINE_DIR}/.agent-signal" "${PIPELINE_DIR}/.pr-url"`. Unchanged by r2 commits. |
| AC5: PR URL 3-layer detection (gh pr list → sidecar → log grep) | PASS (unchanged from r1) | Lines 679–700. Unchanged by r2 commits. |
| AC6: Preflight verifies `--output-format json` support; falls back to text | PASS (unchanged from r1) | Lines 293–313 (Probe 5). Unchanged by r2 commits. |
| AC7: `ralph-pipeline.sh --help` exits 0 | PASS | Confirmed by running `./scripts/ralph-pipeline.sh --help`. Outputs usage text, exits 0. |
| AC8: `pipeline-review.md` report paths use `.harness/state/pipeline/` | PASS (unchanged from r1) | `pipeline-review.md` lines 25, 32, 38. Unchanged by r2 commits. |
| AC9: `definition-of-done.md` clarifies pipeline report locations | PASS (unchanged from r1) | Lines 37–39 of `definition-of-done.md`. Unchanged by r2 commits. |
| AC10: Dry-run tests (`--preflight --dry-run`, `--help`, `--dry-run --max-iterations 3`) pass | PASS | All three variants executed. `--dry-run --max-iterations 1` and `--dry-run --max-iterations 3` both exit 0 with `Status: complete`. `--help` exits 0. |
| AC11: `sh -n` passes on all scripts in `scripts/` | PASS | All 16 files pass `sh -n`. See Static analysis section. |

### Additional r2-specific checks (focused on changed behaviour)

| Change | Verified | Evidence |
|---|---|---|
| **COMPLETE gating**: `run_inner_loop()` returns 6 when tests pass but COMPLETE not signalled | PASS | `ralph-pipeline.sh:572`: `return 6` present. `ralph-pipeline.sh:801–804`: `case 6` handler increments `_inner_cycle` and continues the inner while-loop. |
| **COMPLETE gating**: return 0 (advance to Outer Loop) requires both `_agent_complete -eq 1` AND tests passed | PASS | `ralph-pipeline.sh:563–568`: `if [ "$_agent_complete" -eq 1 ]; then … return 0; fi` runs only after the test phase exits 0. The guard is structurally correct. |
| **`pipeline-outer.md` scope**: docs sync only; PR and codex review removed | PASS | `pipeline-outer.md` line 4: "**Important:** Your scope is documentation sync ONLY. Do NOT run codex review or create a PR." Line 40: "Do NOT create pull requests or run codex review — those are handled by the pipeline." Codex review and PR creation content no longer appear in the file. |
| **Fallback docs prompt in `ralph-pipeline.sh`**: consistent with `pipeline-outer.md` | PASS | `ralph-pipeline.sh:595–600`: fallback `DOCS` heredoc says "Commit documentation changes with: `docs: <description>`" and "Do NOT create a PR or run codex review — those are handled by the pipeline." |
| **dry-run COMPLETE simulation**: `echo COMPLETE > .agent-signal` after `run_claude()` in dry-run | PASS | `ralph-pipeline.sh:415–418`. Block executes after `run_claude()` returns, before sidecar read. The `.agent-signal` file is cleared at cycle start (line 354), then written here. Dry-run path correctly exercises COMPLETE detection. |
| **dry-run comment accuracy**: comment now reads "simulate COMPLETE signal (cleared each cycle start)" | PASS | `ralph-pipeline.sh:415` comment confirmed. Self-review r2 MEDIUM finding (misleading "after first cycle" comment) resolved in commit `d607cdd`. |
| **`report_event "pr-created"` safe JSON**: uses `jq -n --argjson c "$_cycle" --arg u "$_pr_url"` | PASS | `ralph-pipeline.sh:706–707`: `_pr_event="$(jq -n --argjson c "$_cycle" --arg u "$_pr_url" '{"cycle":$c,"url":$u}')"` then `report_event "pr-created" "$_pr_event"`. This resolves the HIGH finding from self-review r2 that was carried from r1. |
| **Self-review r2 HIGH resolved**: `report_event "pr-created"` no longer embeds `_pr_url` via string interpolation | PASS | Confirmed by reviewing commit `d607cdd` diff. The old `"{\"cycle\":${_cycle},\"url\":\"${_pr_url}\"}"` is replaced by jq construction. |

---

## Static analysis

| Command | Result | Notes |
|---|---|---|
| `sh -n scripts/ralph-pipeline.sh` | PASS | No syntax errors |
| `sh -n scripts/ralph` | PASS | No syntax errors |
| `sh -n scripts/ralph-orchestrator.sh` | PASS | No syntax errors |
| `sh -n scripts/ralph-loop.sh` | PASS | No syntax errors |
| `sh -n scripts/ralph-loop-init.sh` | PASS | No syntax errors |
| `sh -n scripts/run-static-verify.sh` | PASS | No syntax errors |
| `sh -n scripts/run-verify.sh` | PASS | No syntax errors |
| `sh -n scripts/run-test.sh` | PASS | No syntax errors |
| `sh -n scripts/commit-msg-guard.sh` | PASS | No syntax errors |
| `sh -n scripts/bootstrap.sh` | PASS | No syntax errors |
| `sh -n scripts/check-template.sh` | PASS | No syntax errors |
| `sh -n scripts/archive-plan.sh` | PASS | No syntax errors |
| `sh -n scripts/codex-check.sh` | PASS | No syntax errors |
| `sh -n scripts/detect-languages.sh` | PASS | No syntax errors |
| `sh -n scripts/new-feature-plan.sh` | PASS | No syntax errors |
| `sh -n scripts/new-language-pack.sh` | PASS | No syntax errors |
| `shellcheck` | NOT RUN | shellcheck not installed — recurring environment gap (INFO) |

---

## Documentation drift

| Doc / contract | In sync? | Notes |
|---|---|---|
| `pipeline-outer.md` — scope restricted to docs sync only | IN SYNC | File now matches the orchestrator's expectation: docs sync only, no codex/PR. The pipeline script handles those phases independently. |
| `ralph-pipeline.sh` fallback `DOCS` heredoc — consistent with `pipeline-outer.md` | IN SYNC | Lines 595–600 in `ralph-pipeline.sh` match the scope restriction applied to `pipeline-outer.md`. |
| `pipeline-inner.md` — COMPLETE/ABORT sidecar instructions | IN SYNC (unchanged from r1) | `pipeline-inner.md` lines 57–72 still instruct agent to write to `.harness/state/pipeline/.agent-signal`. No change. |
| `definition-of-done.md` — pipeline mode report locations | IN SYNC (unchanged from r1) | Lines 37–39: Inner Loop working reports in `.harness/state/pipeline/`, final artifacts in `docs/reports/`. No change. |
| `ralph-pipeline.sh` line 415 comment | IN SYNC | Previously read "after first cycle" (misleading — fires every cycle). Now reads "(cleared each cycle start)". Accurate. |
| `docs/reports/codex-triage-pipeline-robustness.md` | NEW (PASS) | Created in commit `6e49d6a`. Correctly records the 2 WORTH_CONSIDERING + 1 DISMISSED triage result. Both WORTH_CONSIDERING items now addressed. |

### Remaining minor drift (non-blocking, carried from r1)

| Item | Severity | Status |
|---|---|---|
| `ralph-pipeline.sh:670` PR prompt contains hardcoded example URL `echo "https://github.com/..." > .harness/state/pipeline/.pr-url` | MEDIUM | Carried from self-review r1/r2. Non-blocking; agent may copy literal value. Tech-debt candidate. |
| `ralph-pipeline.sh:482–492` inline review fallback omits static verify fallback command | LOW | Minor discrepancy with `pipeline-review.md:30`. Non-blocking. |

---

## Observational checks

- `--dry-run --max-iterations 1`: Pipeline completes in 1 inner cycle + 1 outer cycle. COMPLETE signal written by dry-run simulation block, detected via sidecar Layer 1. Outer Loop runs sync-docs (dry-run), skips codex (not available in env), runs PR phase (dry-run), detects PR via `gh pr list` Layer 1. Status: `complete`. Exit 0.
- `--dry-run --max-iterations 3`: Same flow. Dry-run produces "Warning: no new commits detected (stuck count: 1/3)" — expected because no real commits occur in dry-run. Hook parity check warns on uncommitted changes — expected and non-blocking.
- The dry-run path now correctly simulates COMPLETE via the same `.agent-signal` mechanism used in real execution. The simulation block fires after `run_claude()` (not in the dry-run branch of `run_claude()` itself), which means the sidecar file lifecycle (clear → write → detect) is exercised end-to-end in dry-run.
- `pipeline-outer.md` and the fallback heredoc are consistent. In the dry-run, `.harness/state/pipeline/pipeline-outer.md` was present (from a previous `ralph-loop-init.sh` run), and its content was confirmed as the restricted docs-only version.

---

## Coverage gaps

1. **shellcheck not installed** (INFO): `sh -n` catches syntax errors but not POSIX portability issues, unquoted variables, or unsafe patterns. Recurring environment constraint — cannot be resolved without installing shellcheck.
2. **COMPLETE gating runtime**: The `return 6` path (tests pass, COMPLETE not signalled) is verified by code inspection and dry-run trace. In dry-run, the simulation block always writes COMPLETE, so `return 6` is never actually exercised in dry-run — only in real execution. Behavior of the `case 6` handler in the main loop is confirmed by code reading.
3. **`report_event "pr-created"` jq output validity**: The jq command at line 706 is structurally correct. Runtime validity (jq actually installed, numeric `_cycle`) is verified by preflight (Probe 2) and the fact that `_cycle` is always an integer in the calling context. No additional gap.
4. **AC6 runtime probe**: Probe 5 runs as `skip_dry_run` in dry-run. The actual `--output-format json` probe behavior is verified by code inspection only. Unchanged from r1.
5. **Hardcoded example URL in PR prompt** (MEDIUM, carried): `ralph-pipeline.sh:670` instructs the agent to echo `"https://github.com/..."` literally. If the agent follows this instruction verbatim, `.pr-url` will contain an invalid URL and Layer 2 detection will fail (falling back to Layer 3). Not a regression introduced in r2; was present in r1. Recommend replacing with `gh pr view --json url --jq '.url'`.

---

## Verdict

- **Verified**: AC1–AC11 (all), COMPLETE gating (return 6 + case 6), `pipeline-outer.md` scope restriction, `report_event "pr-created"` jq-safe JSON, dry-run COMPLETE simulation, dry-run comment accuracy
- **Partially verified**: COMPLETE gating `return 6` path (code inspection + dry-run trace; `return 6` itself not exercised in dry-run since simulation writes COMPLETE unconditionally)
- **Not verified**: None (all items have code-level or dry-run evidence)

**Overall verdict: PASS**

All 11 acceptance criteria remain satisfied after the r2 fix-pass. The self-review r2 HIGH finding (`report_event "pr-created"` string interpolation) is confirmed resolved in commit `d607cdd`. No new blocking issues introduced. The two remaining non-blocking items (hardcoded example URL in PR prompt, inline review fallback discrepancy) are carried as known gaps and are candidates for future tech-debt resolution.
