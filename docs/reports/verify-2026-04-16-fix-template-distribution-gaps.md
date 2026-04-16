# Verify report: fix-template-distribution-gaps

- Date: 2026-04-16
- Plan: docs/plans/active/2026-04-16-fix-template-distribution-gaps.md
- Verifier: verifier subagent
- Scope: Template script distribution, commit-msg-guard references, quality-gates cleanup, upgrade.go permission fix, embed test coverage
- Evidence: `docs/evidence/verify-2026-04-16-fix-template-distribution-gaps.log`

## Spec compliance

| Acceptance criterion | Status | Evidence |
| --- | --- | --- |
| AC1: templates/base/scripts/ has 16 scripts | PASS | `find -type f | wc -l` = 16; all 16 names confirmed; all tracked as git mode 100755 |
| AC2: commit-msg-guard.sh exists and git-commit-strategy.md references correct | PASS | File identical to source repo copy; git-commit-strategy.md L69 references it correctly |
| AC3: quality-gates.md has no repo-specific script or nonexistent CI workflow refs | PASS | No matches for check-template/build-tui/check-coverage/check-pipeline-sync/new-language-pack; .github/workflows/ mention is a suggestion/example, not a hard reference |
| AC4: go build ./cmd/ralph/ succeeds | PASS | Exit 0 |
| AC5: go test ./internal/scaffold/... has script existence test and passes | PASS | TestTemplateBaseScriptsExist (embed_test.go L52-93) checks all 16 names + executable perm; static verify shows package ok |
| AC6: go test ./... all pass | PASS | run-static-verify.sh exit 0; all packages ok (cached from earlier run) |
| AC7: upgrade.go writes .sh files with 0755 permission | PASS | filePerm() function added; all 4 os.WriteFile sites use filePerm(d.Path); also covers extensionless "ralph" in scripts/ |

## Static analysis

| Command | Result | Notes |
| --- | --- | --- |
| go vet ./... | EXIT 0, 0 issues | Clean |
| go build ./cmd/ralph/ | EXIT 0 | Embed includes all 16 template scripts |
| HARNESS_VERIFY_MODE=static ./scripts/run-static-verify.sh | EXIT 0 | gofmt ok, go vet clean, all test packages ok |

## Documentation drift

| Doc / contract | In sync? | Notes |
| --- | --- | --- |
| templates/base/.claude/rules/git-commit-strategy.md | Yes | commit-msg-guard.sh reference matches distributed file |
| templates/base/docs/quality/quality-gates.md | Yes | Repo-specific scripts removed; CI workflow mention is suggestive, not assertive |
| templates/base/scripts/ralph L182 | LOW drift | References "scripts/build-tui.sh" which is not distributed; unreachable in practice because guard at L178 requires bin/ralph-tui to exist |
| Template-to-source script parity | Yes | commit-msg-guard.sh, run-verify.sh, ralph all identical to source repo copies |

## Observational checks

- All 16 template scripts have git file mode 100755 and filesystem permission 755
- upgrade.go filePerm() covers both .sh suffix and extensionless "ralph" in scripts/ path
- render.go uses FS metadata for permission (L86) with .sh suffix fallback (L88); go:embed does not preserve execute bits, but the .sh fallback catches most scripts. The extensionless "ralph" is handled by the FS metadata path only if the embed preserves the bit -- this is a known gap addressed by upgrade.go's explicit name check but not by render.go
- Self-review identified filePerm() duplication as tech debt (uncommitted entry in docs/tech-debt/README.md)

## Coverage gaps

1. **render.go "ralph" permission gap**: render.go relies on `d.Info()` execute bit for the extensionless `ralph` script. `go:embed` may not preserve this bit. If it does not, `ralph init` would write `ralph` as 0644 (non-executable). upgrade.go handles this correctly via explicit name check, but render.go does not. This is a **pre-existing gap** (not introduced by this branch) that should be verified by `/test` with a targeted test.

2. **AC5/AC6 results are cached**: The static verify run showed `(cached)` for all test packages. Fresh test execution is needed from `/test` to confirm no regressions.

3. **Uncommitted changes**: `docs/tech-debt/README.md` has an uncommitted filePerm() duplication tech-debt entry. `docs/reports/self-review-*.md` is untracked. These should be committed before PR.

## Verdict

- **Verified**: AC1, AC2, AC3, AC4, AC7 (all fully verified with evidence)
- **Verified (static, needs test confirmation)**: AC5, AC6 (test code exists and is correct; cached results show pass; fresh execution deferred to /test)
- **Not verified (out of scope, pre-existing)**: render.go extensionless "ralph" permission handling via go:embed -- not introduced by this branch, not part of ACs

**Overall: PASS** -- All 7 acceptance criteria are met. One pre-existing LOW-severity documentation drift noted (build-tui.sh reference in ralph script). One pre-existing render.go gap noted for future mitigation. Fresh test execution recommended via /test.
