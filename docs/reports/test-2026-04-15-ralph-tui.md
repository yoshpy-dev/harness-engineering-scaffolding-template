# Test report: ralph-tui

- Date: 2026-04-15
- Plan: docs/plans/active/2026-04-15-ralph-tui/slice-6-ralph-tui.md
- Tester: pipeline-test (autonomous)
- Scope: behavioral tests
- Evidence: `docs/evidence/test-2026-04-15-ralph-tui.log`

## Test execution

| Suite / Command | Tests | Passed | Failed | Skipped | Duration |
| --- | --- | --- | --- | --- | --- |
| `internal/action` | 9 | 9 | 0 | 0 | 3.511s |
| `internal/state` | 12 | 12 | 0 | 0 | 1.632s |
| `internal/ui` | 41 | 41 | 0 | 0 | 1.313s |
| `internal/ui/panes` | 57 | 57 | 0 | 0 | 3.156s |
| `internal/watcher` | 14 | 14 | 0 | 0 | 3.850s |
| `cmd/ralph-tui` | 0 | 0 | 0 | 0 | — |
| **Total** | **133** | **133** | **0** | **0** | **~13.5s** |

## Coverage

- Statement: 79.6% (overall)
- Branch: N/A (Go does not report branch coverage natively)
- Function: N/A
- Notes:
  - `internal/action`: 95.7%
  - `internal/state`: 86.2%
  - `internal/ui`: 88.1%
  - `internal/ui/panes`: 88.9%
  - `internal/watcher`: 78.6%
  - `cmd/ralph-tui`: 0.0% (no test files; deferred to integration tests per plan)
  - `internal/deps`: no test files (pure dependency resolution, no runtime logic)

## Failure analysis

| Test | Error | Root cause | Proposed fix |
| --- | --- | --- | --- |
| (none) | — | — | — |

No test failures.

## Regression checks

| Previously broken behavior | Status | Evidence |
| --- | --- | --- |
| State reader returns zero-value on missing orchestrator file | Fixed | `TestReadFullStatus_NoOrchestrator` passes |
| Watcher graceful on missing directory | Fixed | `TestWatcher_GracefulOnMissingDir` passes |
| Tailer handles missing file without panic | Fixed | `TestTailer_MissingFile` passes |
| Slice name validation rejects shell metacharacters | Fixed | `TestValidateSliceName` (24 subtests) all pass |
| ANSI stripping in log view | Fixed | `TestLogViewANSIStripping`, `TestLogViewAppendLineANSI` pass |

## Test gaps

### From plan test plan — not covered by current Go tests:

1. **`cmd/ralph-tui` unit tests** (flag parsing, initialization logic) — 0% coverage. No test files exist. The plan notes these are deferred to integration-level tests, but no integration tests exist either. **Should be added** for flag parsing at minimum.

2. **`scripts/build-tui.sh` integration test** — Not tested programmatically. Verify agent confirmed build works via direct `go build`. **Covered by other means** (verify agent, manual execution).

3. **`ralph status --json` regression** — No automated comparison test exists. **Should be added** as a shell-level regression test.

4. **`ralph status --no-tui` output** — No automated test. **Should be added** as a shell-level test.

5. **`ralph retry` locklist conflict check** — Not implemented (verify finding AC12 partially met). Cannot test what doesn't exist. **Blocked on implementation**.

6. **`ralph retry` dependency check** — Not implemented (verify finding AC12 partially met). Cannot test what doesn't exist. **Blocked on implementation**.

7. **`ralph abort --slice` single-slice abort** — Go-level `TestAbortSlice` exists and passes. Shell-level integration test does not exist. **Partially covered** by Go unit tests.

8. **Edge case: Go not installed** — Cannot easily test in CI. **Covered by reading build script source** (verify agent confirmed error path exists).

9. **Edge case: `bin/` directory absent** — Not tested. **Should be added** (trivial mkdir-or-fail check in build script).

10. **Edge case: retry target is `running`** — Go-level `TestActionsModel_RunningSliceActions` confirms UI disables retry for running slices. Shell-level `cmd_retry()` status check is not separately unit-tested. **Partially covered** by UI test.

## Verdict

- Pass: **yes** — all 133 tests pass, 0 failures
- Fail: 0
- Blocked: 0
- Coverage: 79.6% overall (below 80% target due to `cmd/ralph-tui` 0% and `internal/deps` no tests)
- Note: Coverage gap is concentrated in `cmd/ralph-tui` (entry point with no test files) and `internal/deps` (no test files). All testable packages exceed 78%.
