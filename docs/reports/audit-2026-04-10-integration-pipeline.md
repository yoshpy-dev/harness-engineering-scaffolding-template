# Harness Audit: Integration Pipeline PR

- Date: 2026-04-10
- Branch: feat/ralph-loop-v2
- Scope: PR全体 — シェルスクリプト、Claude設定、ドキュメント、品質ゲート

## Strengths

1. **構文安全性**: 全16シェルスクリプトが `bash -n` パス
2. **責任分離が明確**: /self-review, /verify, /test の NON-overlap が SKILL.md で明示的に定義
3. **パイプライン順序の一貫性**: canonical order が /work と /loop で一致 (post-implementation-pipeline.md 準拠)
4. **新機能の統合品質**: `--skip-pr` / `--fix-all` フラグの実装が完全で、引数パーサー・ロジック・ログ出力すべて整合
5. **多層防御**: pre_bash_guard.sh がシークレット漏洩、force push、危険パターンを検知
6. **always-on context が適切なサイズ**: CLAUDE.md (32行) + AGENTS.md (105行) = 137行、~1,500 tokens

## Pain Points (この PR で修正すべき)

| # | 重要度 | 問題 | ファイル | 推奨 |
|---|--------|------|---------|------|
| 1 | HIGH | `docs/recipes/ralph-loop.md` Quick Start が古い単一ファイルワークフローを記述 | docs/recipes/ralph-loop.md | 新しいディレクトリベースフローに更新 |
| 2 | HIGH | `ralph-orchestrator.sh` の heredoc delimiter が unquoted (`MERGE_EOF`, `PR_EOF`) | scripts/ralph-orchestrator.sh | `<<'MERGE_EOF'`, `<<'PR_EOF'` に修正 |
| 3 | MEDIUM | `post-implementation-pipeline.md` に integration pipeline の記述がない | .claude/rules/post-implementation-pipeline.md | Ralph Loop 用セクション追加 |
| 4 | MEDIUM | `loop/SKILL.md` で codex-review フェーズが明示されていない | .claude/skills/loop/SKILL.md | After the loop セクションに追記 |
| 5 | MEDIUM | `definition-of-done.md` の Ralph Loop チェックリストが統合パイプラインの詳細を未記述 | docs/quality/definition-of-done.md | チェックリスト項目を詳細化 |

## Pain Points (フォローアップ — 次回以降)

| # | 重要度 | 問題 | 推奨 |
|---|--------|------|------|
| 6 | HIGH | `commit-msg-guard.sh` が git hook として registered されていない | `.claude/hooks/` への integration を検討 |
| 7 | HIGH | testing.md の edge case / 80% coverage rule が CI で enforced されていない | CI workflow に coverage check 追加 |
| 8 | MEDIUM | multi-location pipeline order の同期チェック機構がない (6ファイルに分散) | `check-pipeline-sync.sh` スクリプト作成 |
| 9 | MEDIUM | main/master への直接 commit を防ぐ pre-commit hook がない | `.claude/hooks/` に branch guard 追加 |
| 10 | LOW | `gh pr create 2>&1` が stderr を PR URL に混入する可能性 | `2>/dev/null` に変更 |

## Missing Guardrails

- **Integration pipeline 同期検証**: `post-implementation-pipeline.md` が canonical order の single source of truth を謳うが、integration pipeline variant をカバーしていない
- **Heredoc quoting enforcement**: `git-commit-strategy.md` で `<<'EOF'` を推奨するが、既存の `MERGE_EOF` / `PR_EOF` が未修正
- **CI coverage gate**: `docs/quality/` で 80% coverage を要求するが、CI に enforcement なし

## Proposed Promotions (prose → code)

| 現在 (prose) | 推奨 (code) | 理由 |
|-------------|-------------|------|
| git-commit-strategy.md "Safety Bracket" guidance | `pre-commit-checkpoint.sh` hook | 大規模リファクタリング前の checkpoint 忘れ防止 |
| testing.md "edge case per logic change" | tester subagent checklist に追加 | 繰り返し指摘される項目 |
| post-implementation-pipeline.md "update all 6 locations" | `check-pipeline-sync.sh` CI check | 手動同期は信頼性が低い |

## Simplifications Worth Trying

1. **`run-static-verify.sh` と `run-test.sh` の統合**: 両者とも `run-verify.sh` の wrapper (3行)。`HARNESS_VERIFY_MODE` 環境変数で分岐するなら、`run-verify.sh --mode static` / `run-verify.sh --mode test` に統一可能
2. **レポートファイル命名の標準化**: 古い命名 (`audit-harness-2026-04-09-pr5.md`) と新しい命名 (`self-review-integration-pipeline.md`) が混在。テンプレートで統一推奨

## Verdict

**マージ可 (条件付き)**: CRITICAL 問題なし。HIGH 2件 (#1, #2) をこの PR で修正推奨。残りはフォローアップ。
