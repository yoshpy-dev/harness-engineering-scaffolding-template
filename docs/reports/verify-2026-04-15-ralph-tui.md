# Verify report: ralph-tui

- Date: 2026-04-15
- Plan: docs/plans/active/2026-04-15-ralph-tui/slice-6-ralph-tui.md
- Verifier: pipeline-verify (autonomous)
- Scope: spec compliance + static analysis + documentation drift
- Evidence: `docs/evidence/verify-2026-04-15-ralph-tui.log`

## Spec compliance

| Acceptance criterion | Status | Evidence |
| --- | --- | --- |
| `cmd/ralph-tui/main.go` initializes all components and starts TUI with `tea.NewProgram` | met | main.go imports state/watcher/ui/action, calls `state.ReadFullStatus()`, `watcher.New()`, `action.NewExecutor()`, `ui.New()`, and `tea.NewProgram(model)` at line 79 |
| `go build -o bin/ralph-tui ./cmd/ralph-tui` produces single binary | met | Build succeeds with exit 0 |
| Binary size < 30MB with `-ldflags="-s -w"` | met | 4.0 MB with ldflags (5.7 MB without) |
| `--version` flag shows git commit hash | met | Output: `ralph-tui dev (commit: 085196e, built: 2026-04-15T08:52:06Z)` |
| `--no-tui` flag in `cmd_status()` | met | scripts/ralph line 149: `--no-tui) _no_tui=1` |
| TTY + binary + no `--no-tui` → TUI launch | met | scripts/ralph line 176: TTY detection + binary existence + outdated check |
| Non-TTY or `--no-tui` → table output | met | Falls through to table output at line 199+ |
| `--json` → existing JSON output (no TUI impact) | met | JSON mode returns at line 171 before TUI check |
| Binary missing → table fallback | met | `[ -x "$_tui_bin" ]` check at line 176 |
| Outdated binary → warning + fallback | met | `find -newer` check at line 178, warning at line 180 |
| `ralph retry <slice-name>` subcommand exists | met | `cmd_retry()` at line 220 |
| `retry` validates PID/status/locklist/parallel limit | partially met | Status check (lines 237-257), orchestrator check (261-264), parallel limit (267-285) implemented. **Locklist conflict check and dependency check are NOT implemented** despite being listed in the implementation outline (steps b and d) and the AC text. |
| `ralph abort --slice <name>` flag exists | met | `--slice` flag at line 321 |
| `abort --slice` limits existing abort flow to single slice | met | PID kill (340-347), state archive (372-379), worktree removal (402-407), audit log (431-442) all scoped to target slice |
| `build-tui.sh` builds to `bin/ralph-tui` | met | build-tui.sh line 33-44: `go build ... -o "$_output" ./cmd/ralph-tui` |
| `.gitignore` has `bin/` | met | .gitignore line 7 |

## Static analysis

| Command | Result | Notes |
| --- | --- | --- |
| `go vet ./...` | pass | Clean, no warnings |
| `go build ./cmd/ralph-tui` | pass | Exit 0, binary produced |
| `gofmt` | pass | 0 issues |
| `./scripts/run-static-verify.sh` | pass | All verifiers passed |

## Documentation drift

| Doc / contract | In sync? | Notes |
| --- | --- | --- |
| `CLAUDE.md` | yes | No TUI-specific additions needed per manifest ("スコープ外") |
| `AGENTS.md` | yes | No TUI-specific additions needed per manifest |
| `.claude/rules/` | yes | No rules reference TUI behavior; existing rules unaffected |
| `README.md` | yes | `ralph status` / `ralph abort` usage still correct; new subcommands (retry, --no-tui) are additive |
| `docs/plans/active/2026-04-15-ralph-tui/_manifest.md` | yes | Manifest scope and dependency graph match implementation |
| `scripts/ralph` help text | yes | Usage block includes retry, --no-tui, abort --slice |

## Observational checks

- **Bubble Tea v2 API**: main.go uses `tea.View` struct with `AltScreen` field (v2 pattern) instead of `tea.WithAltScreen()` option (v1 pattern). This is correct for the v2 API.
- **State injection**: Initial state is set via `m.ui.Panes.Slices = fmt.Sprintf(...)` (string, not structured data). Full structured state comes via `StateUpdatedMsg` on first watcher event. This works but is a weak initial render.
- **Error handling in Update**: `appModel.Update` silently discards `ReadFullStatus` errors (self-review MEDIUM finding, not a spec violation).
- **No test files for `cmd/ralph-tui/`**: Static analysis confirms `[no test files]`. Tests for this package are deferred to integration-level tests per the plan.

## Coverage gaps

- **Locklist conflict check in retry**: The AC mentions "locklist" as a validation the retry command should perform. The implementation outline (step b) describes checking for shared-file conflicts with currently running slices. This check is absent. **Risk**: a retried slice could write to the same shared files as a running slice, causing data races.
- **Dependency check in retry**: The implementation outline (step d) describes verifying all dependencies are complete before retry. This check is absent. **Risk**: a retried slice could start before its dependencies are complete, causing build or test failures.
- **Build script end-to-end**: `scripts/build-tui.sh` was not executed in this verification (only direct `go build` was tested). The script's Go version check and ldflags injection were verified by reading the source.

## Verdict

- Verified: AC 1-11, AC 13-16 (15 of 16 acceptance criteria fully met)
- Partially verified: AC 12 (retry validates status and parallel limit, but missing locklist and dependency checks)
- Not verified: None (all criteria have evidence)

**Overall**: **partial** — 15/16 criteria fully met, 1/16 partially met due to missing locklist and dependency validation in `cmd_retry()`.
