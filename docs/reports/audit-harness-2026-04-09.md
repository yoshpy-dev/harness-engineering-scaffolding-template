# Harness audit memo — 2026-04-09

Trigger: post-implementation pipeline で `/sync-docs` と `/codex-review` がスキップされ、不完全な状態で `/pr` に到達した。

## インシデント分析

### 発生事象

Codex レビューで 4件の ACTION_REQUIRED が検出され、ユーザーが「修正する」を選択。修正後の再検証パイプラインで:

```
期待: /self-review → /verify → /test → /sync-docs → /codex-review → /pr
実際: /self-review → /verify → /test → /pr  ← sync-docs と codex-review がスキップ
```

### 根本原因 (2つ)

| # | 原因 | カテゴリ | ファイル |
|---|------|---------|---------|
| 1 | `/codex-review` SKILL.md の Case A 再実行フローに `/sync-docs` が記載されていなかった | **スキル定義バグ** | `codex-review/SKILL.md:88` |
| 2 | パイプライン順序の single source of truth が存在せず、各スキルが独自に順序を定義していた | **構造的問題** | 複数ファイルに分散 |

### 寄与因子

- codex-review SKILL.md を作成した時点で `/sync-docs` ステップがまだ存在しなかった可能性（後から追加されたステップが既存スキルに反映されなかった）
- 再実行時にエージェントが「前回のフルパイプライン」ではなく「codex-review SKILL.md の指示」に従った

## 適用した修正

| # | 修正内容 | ファイル |
|---|---------|---------|
| 1 | codex-review SKILL.md の Case A/B に `/sync-docs` を追加 | `.claude/skills/codex-review/SKILL.md` |
| 2 | `.claude/rules/post-implementation-pipeline.md` を新規作成 — 正規順序の single source of truth | `.claude/rules/post-implementation-pipeline.md` |
| 3 | `definition-of-done.md` にパイプライン順序とパイプラインモード対応を追加 | `docs/quality/definition-of-done.md` |
| 4 | `quality-gates.md` にパイプラインモードのゲート定義を追加 | `docs/quality/quality-gates.md` |

## 広範な監査結果

### 強み

- post-implementation pipeline の順序は `CLAUDE.md`, `AGENTS.md`, `work/SKILL.md`, `loop/SKILL.md`, `subagent-policy.md` で一貫していた（codex-review の再実行フローだけが不整合）
- `ralph-pipeline.sh` の Outer Loop は正しい順序を実装していた（sync-docs → codex-review → PR）
- Self-review/Verify/Test の責任分離は明確で重複がない
- Hook parity check がパイプラインモードで hooks 非実行の問題を補完している
- Preflight probe が実行前に前提条件を検証している

### 痛点

| 痛点 | 影響 | 推奨対応 |
|------|------|---------|
| パイプライン順序が6ファイルに分散定義されていた | 更新漏れによるスキップバグ | `post-implementation-pipeline.md` で集約済み（今回修正） |
| `quality-gates.md` がパイプラインモードを知らなかった | パイプラインモードの品質基準が未定義 | 今回更新済み |
| `definition-of-done.md` が `/work` フローのみ対応 | パイプラインモードの完了判定基準がなかった | 今回更新済み |
| CI ワークフローが `verify.yml` と `check-template.yml` のみ | quality-gates が「integration and e2e checks」を列挙するが未実装 | quality-gates を実態に合わせて修正済み（aspirational として分離） |

### 欠けているガードレール

| ガードレール | 現状 | 推奨 |
|-------------|------|------|
| パイプライン順序のスキップ検出 | 人間の目視のみ | `/pr` の pre-checks にパイプライン全ステップのレポート存在確認を追加 |
| パイプラインモードの品質ゲート | 未文書化 | `quality-gates.md` に追加済み（今回修正） |
| スキル間の順序整合性チェック | なし | `audit-harness` スキルのチェック項目に追加 |

### Prose → Code への昇格候補

| 現在の場所 | 候補のコード化先 | 理由 |
|-----------|----------------|------|
| `post-implementation-pipeline.md` の順序定義 | `scripts/run-pipeline-check.sh` — 全レポートの存在確認スクリプト | `/pr` の pre-check で使えば順序スキップを自動検出 |
| CRITICAL self-review 発見の無視ポリシー | `ralph-pipeline.sh` 内の configurable threshold | 現在はハードコードされたコメント。設定可能にすべき |

### 検討すべき簡素化

| 対象 | 提案 |
|------|------|
| 6ファイルに分散したパイプライン順序定義 | `post-implementation-pipeline.md` を正とし、他は「see post-implementation-pipeline.md」で参照のみにする（ただし各スキルが自己完結的である利点とのトレードオフ） |

## 結論

今回のインシデントは **構造的な問題（single source of truth の不在）** と **スキル定義のバグ** の組み合わせ。修正として:
1. 即座に `/codex-review` SKILL.md を修正
2. 再発防止として `post-implementation-pipeline.md` を新規作成し正規順序を集約
3. quality docs のドリフトを修正

`post-implementation-pipeline.md` の「Where this order is referenced」セクションが今後の更新漏れを防ぐチェックリストとして機能する。
