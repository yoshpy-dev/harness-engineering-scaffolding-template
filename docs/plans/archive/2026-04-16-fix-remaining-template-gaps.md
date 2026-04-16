# fix-remaining-template-gaps

- Status: Ready
- Owner: Claude Code
- Date: 2026-04-16
- Related request: fix-remaining-template-gaps
- Related issue: PR #19 (追加コミット)
- Branch: fix/template-distribution-gaps (既存)
- Flow: 標準フロー (/work)

## Objective

PR #19 で対応しきれなかった軽微なテンプレート配布ギャップ3件を修正する。

## Scope

1. `docs/reports/templates/codex-triage-report.md` を `templates/base/` に追加
2. `docs/recipes/ralph-loop.md` を `templates/base/` に追加
3. `.github/workflows/verify.yml` のテンプレート版を `templates/base/` に作成

## Non-goals

- ソースリポの CI ワークフローの変更
- 既存スクリプトの変更

## Affected areas

- `templates/base/docs/reports/templates/` — 新規ディレクトリ + ファイル
- `templates/base/docs/recipes/` — 新規ファイル
- `templates/base/.github/workflows/` — 新規ディレクトリ + ファイル

## Acceptance criteria

- [ ] AC1: `templates/base/docs/reports/templates/codex-triage-report.md` が存在する
- [ ] AC2: `templates/base/docs/recipes/ralph-loop.md` が存在する
- [ ] AC3: `templates/base/.github/workflows/verify.yml` が存在し、`./scripts/run-verify.sh` を実行する
- [ ] AC4: `go build ./cmd/ralph/` 成功
- [ ] AC5: `go test ./...` 全パス

## Implementation outline

### Slice 1: codex-triage-report.md + ralph-loop.md コピー
### Slice 2: 汎用 verify.yml 作成

## Verify plan

- `go build ./cmd/ralph/`, `go test ./...`, `./scripts/run-verify.sh`

## Test plan

- 既存テスト全パス

## Risks and mitigations

低リスク。ファイル追加のみ。

## Progress checklist

- [x] Plan reviewed
- [ ] Slice 1: レポートテンプレート + レシピのコピー
- [ ] Slice 2: 汎用 verify.yml の作成
- [ ] 検証パス
- [ ] PR に追加プッシュ
