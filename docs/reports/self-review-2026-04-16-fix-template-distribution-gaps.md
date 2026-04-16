# Self-review report: fix-template-distribution-gaps

- Date: 2026-04-16
- Plan: docs/plans/active/2026-04-16-fix-template-distribution-gaps.md
- Reviewer: reviewer subagent
- Scope: 6 commits, 20 files changed (+4043 / -8), branch fix/template-distribution-gaps

## Evidence reviewed

- `git diff main...fix/template-distribution-gaps` -- full diff (20 files)
- Byte-for-byte comparison of all 16 template scripts against their `scripts/` source -- all identical
- `internal/cli/upgrade.go` -- new `filePerm()` function and 4 call sites
- `internal/scaffold/render.go` -- existing permission logic (L84-90) for comparison
- `internal/scaffold/embed_test.go` -- new `TestTemplateBaseScriptsExist`
- `templates/base/docs/quality/quality-gates.md` -- quality-gates cleanup
- `templates/base/scripts/commit-msg-guard.sh` -- new script (identical to `scripts/commit-msg-guard.sh`)
- `docs/tech-debt/README.md` -- checked for stale/missing entries

## Findings

| Severity | Area | Finding | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| MEDIUM | maintainability | `filePerm()` in upgrade.go diverges from `render.go` permission logic. `render.go` (L86) checks `d.Info().Mode().Perm()&0111` from the embedded FS, then falls back to `.sh` suffix. `filePerm()` uses only name-based heuristics (`.sh` suffix + hardcoded `"ralph"` check). Both work today, but the logic is duplicated with different strategies -- a new extensionless executable added to templates would need updates in `filePerm()` but not `render.go`. | `render.go:84-90` vs `upgrade.go:20-29` | Extract a shared `IsExecutable(path string) bool` function, or make `filePerm()` check the embedded FS metadata like `render.go` does. Low urgency since `ralph` is currently the only extensionless script. |
| MEDIUM | maintainability | `strings.Contains(path, "scripts")` in `filePerm()` (L25) is a loose substring match. A template file at a hypothetical path like `descriptionsralph` or `my-scripts-backup/ralph` would falsely match. The current template tree has no such paths, but the check is fragile for a function that will persist. | `upgrade.go:25` | Use `strings.Contains(path, "scripts/")` (with trailing slash) or `strings.HasPrefix(filepath.Dir(path), "scripts")` for a tighter match. |
| LOW | maintainability | No unit test for `filePerm()`. The function has 3 branches (`.sh` suffix, `ralph` in scripts, default 0644) and is called 4 times. The test in `embed_test.go` checks on-disk permissions of template files but does not exercise the upgrade path's permission logic. | grep for `filePerm` -- only production call sites, no test references | Add a table-driven test in `internal/cli/upgrade_test.go` covering each branch. Not blocking. |
| LOW | readability | Comment on `filePerm()` (L18) says "shebang-bearing extensionless files" but the function does not actually inspect file content for shebangs -- it hardcodes the name "ralph". The comment oversells the generality. | `upgrade.go:17-18` | Narrow the comment to match actual behavior: "the extensionless `ralph` script" rather than implying a general shebang detection. |

## Positive notes

- All 16 template scripts are byte-identical to their source in `scripts/`. No accidental modifications, no stale copies.
- `commit-msg-guard.sh` is a clean, well-structured POSIX sh script with appropriate secret-detection patterns and conventional-commit validation.
- The `quality-gates.md` cleanup correctly removes 3 repo-specific references (`check-template.sh`, `check-coverage.sh`, `check-pipeline-sync.sh`) and the hardcoded CI workflow paths, replacing them with actionable guidance ("add to your CI workflow").
- The test in `embed_test.go` guards against future regressions by verifying both existence and executable permissions on Unix, with a `runtime.GOOS` skip for Windows.
- Permission fix in `upgrade.go` is applied consistently across all 4 `os.WriteFile` call sites (ActionAutoUpdate, ActionConflict overwrite, ActionConflict force, ActionAdd).

## Tech debt identified

| Debt item | Impact | Why deferred | Trigger to pay down | Related plan/report |
| --- | --- | --- | --- | --- |
| `filePerm()` in upgrade.go duplicates permission logic from render.go with different strategies (name-based vs FS-metadata-based) | A new extensionless executable in templates would need updates in two places with different fix patterns | Scope of this PR is distribution gaps, not refactoring the permission system | Adding a second extensionless executable to templates, or any future permission-related bug | self-review-2026-04-16-fix-template-distribution-gaps.md |

## Recommendation

- Merge: YES -- no CRITICAL or HIGH findings. The MEDIUM findings are maintainability concerns about the `filePerm()` implementation that work correctly today. They do not introduce bugs or regressions.
- Follow-ups:
  - Tighten `strings.Contains(path, "scripts")` to `strings.Contains(path, "scripts/")` (trivial fix, can be done in this PR or a follow-up).
  - Consider extracting shared permission logic between `render.go` and `upgrade.go` in a future refactor.
  - Add a unit test for `filePerm()` in a future PR.
