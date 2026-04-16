# Self-review: feat/ralph-cli-tool

- Date: 2026-04-16
- Reviewer: reviewer subagent
- Verdict: **MERGE** (after fixes)

## Findings

| Severity | File | Description | Status |
|----------|------|-------------|--------|
| HIGH | scaffold/embed.go | PackFS path traversal risk — unsanitized lang param | Fixed (f6fa2d0) |
| HIGH | cli/doctor.go | Silently discarded config error | Fixed (f6fa2d0) |
| HIGH | cli/doctor.go | runDoctor returns nil on failures | Fixed (f6fa2d0) |
| MEDIUM | cli/status.go | runStatusTable is dead alias | Noted (Phase 6b) |
| MEDIUM | upgrade/diff.go | String concat instead of filepath.Join | Fixed (f6fa2d0) |
| MEDIUM | cli/status.go | --json flag not producing JSON | Tech debt recorded |
| LOW | cli/root.go | Duplicated version vars | Documented |
| LOW | cli/status.go | _ = consumed discards return | Acceptable |

## Positive observations

- Clean package separation (scaffold, upgrade, config, prompt)
- Manifest roundtrip tested. Diff engine has good edge-case tests
- install.sh verifies checksums, uses set -eu, trapped temp dir
- all:templates embed directive correctly includes dotfiles
