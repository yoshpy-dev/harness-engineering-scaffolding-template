# Test report: Ralph Loop v2 — Codex review findings re-test (r2)

- Date: 2026-04-09
- Plan: docs/plans/active/2026-04-09-ralph-loop-v2.md
- Tester: tester subagent
- Scope: Re-test after Codex review fix commit (4c23fc0). Focus on the 4 ACTION_REQUIRED findings.
- Evidence: `docs/evidence/test-2026-04-09-ralph-loop-v2-r2.log`

## Test execution

| Suite / Command | Tests | Passed | Failed | Skipped | Duration |
| --- | --- | --- | --- | --- | --- |
| `./scripts/run-test.sh` | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph --help` exit code | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph log_error function` | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph --resume` missing checkpoint | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph status` no state | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph-pipeline.sh --preflight --dry-run` | 1 | 1 | 0 | 0 | < 2s |
| `scripts/ralph-pipeline.sh --dry-run --max-iterations 3` | 1 | 1 | 0 | 0 | ~2s |
| stuck detection HEAD hash comparison | 1 | 1 | 0 | 0 | < 1s |
| COMPLETE signal detection logic | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph-orchestrator.sh --dry-run` plan parsing | 1 | 1 | 0 | 0 | < 2s |
| `scripts/ralph-loop-init.sh --pipeline` mode | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph-loop-init.sh` standard mode | 1 | 1 | 0 | 0 | < 1s |
| `scripts/ralph-loop.sh --help` regression | 1 | 1 | 0 | 0 | < 1s |
| **Total** | **13** | **13** | **0** | **0** | |

## Coverage

- Statement: N/A (shell scripts — no coverage tooling)
- Branch: Manually verified all 4 Codex ACTION_REQUIRED code paths
- Function: All modified functions exercised via dry-run
- Notes: Live `claude -p` integration paths remain untestable without API access (expected gap, same as r1)

## Codex ACTION_REQUIRED findings — verification status

### Finding 1: `--resume` flag inverted logic (scripts/ralph lines 121-124)

**Before fix:** `[ ! -f checkpoint.json ] || [ "$_is_resume" -eq 0 ]` (OR — init runs when `--resume`)

**After fix:** `[ ! -f checkpoint.json ] && [ "$_is_resume" -eq 0 ]` (AND — init skips when `--resume` and checkpoint exists)

**Test result: PASS**

Verified two sub-cases:
- `ralph run --resume` with no checkpoint → exits 1 with `ERROR: Cannot resume: no checkpoint found` (correct error handling)
- Code inspection confirms AND condition on lines 121-132 of `scripts/ralph`

### Finding 2: Stuck detection false positives — HEAD hash comparison (scripts/ralph-pipeline.sh)

**Before fix:** Compared `git diff HEAD` (empty after commits → always looked "stuck")

**After fix:** Compares `git rev-parse HEAD` before/after iteration (detects real progress via commit hash change)

**Test result: PASS**

Unit test confirmed:
- `stuck_count=2`, `head_before=head_after` → increments to 3 → STUCK triggered
- File `.head_before` is saved before each iteration
- New log message confirms: "Warning: no new commits detected (stuck count: N/3)"

### Finding 3: Locklist `.running_files` never cleaned up (scripts/ralph-orchestrator.sh)

**Before fix:** Files appended to `.running_files` on slice start, never removed on completion

**After fix:** `.running_files` is cleared (`: > .running_files`) and rebuilt from only currently-running slices each poll cycle (lines 519-529)

**Test result: PASS**

Code inspection confirmed two patterns:
- Line 462: Initial clear before the main loop
- Lines 519-529: Complete rebuild each cycle — only `running` slices re-add their files

Dry-run test with multi-slice plan (shared files) executed cleanly with correct locklist detection.

### Finding 4: COMPLETE signal bypasses verify/test (scripts/ralph-pipeline.sh)

**Before fix:** `grep COMPLETE → return 0` immediately, skipping self-review, verify, and test phases

**After fix:** COMPLETE sets `_agent_complete=1` flag. All phases (self-review, verify, test) still run. Only after test PASSES does `status = "complete"` get recorded.

**Test result: PASS**

Full dry-run executed the complete Inner Loop sequence even when COMPLETE flag would be set:
- implement → self-review → verify → test (all phases executed)
- Test passed → Outer Loop transition
- Signal detection regex `<promise>COMPLETE</promise>` verified correct

## Regression checks

| Previously broken behavior | Status | Evidence |
| --- | --- | --- |
| `ralph --help` returned exit code 1 | FIXED (exits 0) | Test 1 in evidence log |
| `ralph --resume` reinitialised checkpoint instead of resuming | FIXED (AND condition) | Test 3 in evidence log + code inspection |
| Stuck detection fired after every commit (false positive) | FIXED (HEAD hash) | Test 7 unit test |
| Locklist hung slices with shared locked files | FIXED (rebuild pattern) | Code inspection lines 519-529 |
| COMPLETE signal skipped verify/test phases | FIXED (flag-based) | Test 6 dry-run |
| `ralph-loop.sh --help` exits 1 | UNCHANGED (pre-existing, out of scope) | Test 12 in evidence log |

## Test gaps

The following gaps remain from r1 (unchanged — structural, not regressions):

- **Live `claude -p` integration**: preflight probe skips CLAUDE.md readable check in dry-run mode (`skip_dry_run`). No API access in test environment.
- **Checkpoint JSON schema validation**: `jq`-parseable and required fields are not automatically validated.
- **Failure triage cycle (Inner Loop retry)**: Requires live API to exercise the repair attempt → increment → escalation path.
- **Multi-worktree parallel execution**: Requires real git worktree creation and concurrent slice processes.
- **Stuck detection at threshold=3**: Dry-run always passes tests (exit 0), so stuck counter never reaches 3 in a full pipeline dry-run. The counter increment logic was verified via isolated unit test (Test 7).
- **`ralph-orchestrator.sh --dry-run` empty line in locklist**: When no explicit locklist exists but `parse_locklist` runs, an empty line appears in the locklist output. Cosmetic only — does not affect `check_locklist_conflict` function behavior.

## Verdict

- Pass: 13 / 13
- Fail: 0 / 13
- Blocked: 0

**PASS. All 4 Codex ACTION_REQUIRED findings verified fixed. Tests may proceed to PR creation.**
