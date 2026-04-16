# Walkthrough: fix-template-distribution-gaps

## Problem

`ralph init` で生成されるプロジェクトが、ドキュメント（CLAUDE.md, rules, skills）で参照しているスクリプト群を含んでおらず、開発フロー全体が動作しない。

## Solution

### 1. テンプレートにスクリプトを配布 (ff25006, 84fed56)

`scripts/` から `templates/base/scripts/` に16スクリプトをコピー。`go:embed` により `ralph init` 実行時にターゲットプロジェクトに展開される。

**配布スクリプト一覧:**
- 検証: `run-verify.sh`, `run-static-verify.sh`, `run-test.sh`, `detect-languages.sh`
- プラン管理: `archive-plan.sh`, `new-feature-plan.sh`, `new-ralph-plan.sh`
- Codex: `codex-check.sh`
- Ralph Loop: `ralph-loop-init.sh`, `ralph-loop.sh`, `ralph`, `ralph-config.sh`, `ralph-orchestrator.sh`, `ralph-pipeline.sh`, `ralph-status-helpers.sh`
- Git安全: `commit-msg-guard.sh`

### 2. quality-gates.md の修正 (62e8c76)

テンプレート版 `quality-gates.md` からこのリポ固有のスクリプト参照（`check-template.sh`, `check-coverage.sh`, `check-pipeline-sync.sh`）と存在しない CI ワークフロー参照を削除。

### 3. upgrade.go のパーミッション修正 (d644bf1)

`ralph upgrade` で `.sh` ファイルが `0644` で書き込まれ実行不可になるバグを修正。`filePerm()` ヘルパーを追加し、`.sh` ファイルと extensionless `ralph` に `0755` を付与。

### 4. Codex 指摘への対応 (7cd1bca)

Codex レビューで検出されたソーススクリプトのバグ3件を修正:
1. `ralph-pipeline.sh`: `commit-msg-guard.sh` を stdin パイプではなく一時ファイル経由で呼び出し
2. `new-ralph-plan.sh`: 無効な `--slices` フラグを `--unified-pr` に修正
3. `ralph`: plan 自動検出に `sort -r` を追加し決定論的に最新プランを選択

### 5. テスト (097b506)

`TestTemplateBaseScriptsExist` を追加。16スクリプトの存在と実行パーミッションを検証。

## Files changed (30 files, +4341/-14)

| Category | Files | Lines |
|----------|-------|-------|
| Template scripts (new) | 16 files in `templates/base/scripts/` | +3836 |
| Script bug fixes | `scripts/ralph-pipeline.sh`, `scripts/ralph`, `scripts/new-ralph-plan.sh` | +13/-5 |
| Go code | `internal/cli/upgrade.go`, `internal/scaffold/embed_test.go` | +68/-4 |
| Docs | quality-gates.md, plan, reports, repo-map, tech-debt, README | +424/-5 |

## Known gaps (tech-debt)

- `filePerm()` in `upgrade.go` diverges from `render.go` permission logic (name-based vs FS-metadata-based)
- Template `ralph` L182 references `build-tui.sh` which is not distributed (unreachable code path)
