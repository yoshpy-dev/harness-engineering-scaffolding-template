# Walkthrough: mojibake-postedit-guard

- Date: 2026-04-17
- Branch: `chore/mojibake-postedit-guard`
- Commits: 11
- Files changed: 24 (+1724 / -12)
- Plan: `docs/plans/archive/2026-04-17-mojibake-postedit-guard.md` (archived on PR creation)

## TL;DR

Claude Code の `Write` / `Edit` / `MultiEdit` が SSE チャンク境界で
マルチバイト文字を壊し U+FFFD (replacement char) を混入させる既知の
問題に対して、**PostToolUse フック** で検出→`exit 2` により Claude に
再編集を促す暫定対策を導入。合わせて、Codex レビューで浮上した既存
フック `post_edit_verify.sh` の **payload 抽出バグ**（top-level
`file_path` を見ていたため jq 環境下で常に空）を修正し、
`.harness/state/edited-files.log` が初めて正しく populate されるように
なった。

## コミット構造（11 本）

| # | SHA | 種別 | 目的 |
|---|---|---|---|
| 1 | `22642c9` | feat | フック本体 + allowlist + 11 ケースのスモークテスト + `scripts/verify.local.sh` + `scripts/check-sync.sh` 除外 |
| 2 | `3311dc6` | feat | `PostToolUse` matcher を `Edit\|Write\|MultiEdit` に拡張、`check_mojibake.sh` を登録（ルート + templates/base 同期） |
| 3 | `911c5ac` | docs | `AGENTS.md` Repo map に 1 行注記（撤去条件: Issue #43746 解決） |
| 4 | `7c4cc9e` | chore | plan の Status を implementation complete に更新 |
| 5 | `1321cd0` | refactor | Self-review LOW 指摘の先取り修正（test cleanup scope / contract note） |
| 6 | `58225fb` | docs | self-review / verify / test / sync-docs / tech-debt のレポート追加 |
| 7 | `306b23a` | fix | Codex P3/P2/P1 対応（`PostToolUseFailure` matcher 対称化 / `HARNESS_VERIFY_MODE` 対応 / `dirname` linked tools） |
| 8 | `e21c883` | docs | pipeline 再実行レポート追記 |
| 9 | `29d71a2` | fix | `post_edit_verify.sh` が `tool_input.file_path` を抽出するよう修正（既存バグ、matcher 拡張で顕在化） |
| 10 | `eafdb0b` | docs | pipeline 再々実行レポート追記 |
| 11 | `f18e418` | docs | Codex 収束記録 |

## レビュー導線（おすすめ読み順）

1. **Plan**: `docs/plans/archive/2026-04-17-mojibake-postedit-guard.md`
2. **フック本体**: `.claude/hooks/check_mojibake.sh`（93 行、コメント多め）
3. **allowlist**: `.claude/hooks/mojibake-allowlist`
4. **settings.json 変更**: `.claude/settings.json` の `PostToolUse` と `PostToolUseFailure` マッチャ
5. **post_edit_verify 修正**: `.claude/hooks/lib_json.sh` と `.claude/hooks/post_edit_verify.sh`
6. **テスト**: `tests/test-check-mojibake.sh`（11 ケース）+ `tests/fixtures/payloads/*.json`
7. **verify.local.sh**: `scripts/verify.local.sh`（mode split 対応）
8. **パイプラインレポート**: `docs/reports/{self-review,verify,test,sync-docs,codex-triage}-mojibake-postedit-guard.md`

## 重要な設計判断

### 1. allowlist による opt-out 機構

初版プランは「ファイルに U+FFFD があれば常に exit 2」だったが、Codex 事前
アドバイザリで「既存の U+FFFD 含有ファイルを編集するたびに無限ループする」
リスクを指摘された。解決策として **`.claude/hooks/mojibake-allowlist` を
導入**し、glob パターンで opt-out 可能にした。デフォルトでは以下を除外：

- `.claude/hooks/check_mojibake.sh`（自己検知防止）
- `tests/fixtures/**`（テストフィクスチャ）
- `docs/plans/**/*mojibake*.md` / `docs/reports/**/*mojibake*.md`

### 2. jq 必須化 + fail-open-with-warning

jq 無し環境で silent no-op にならないよう、jq 欠落時は stderr に警告を
出して `.harness/state/mojibake-jq-missing` マーカーを作り、exit 0（CI 未
整備環境を壊さない）。既存ガード無しより弱くならない設計。

### 3. PostToolUse matcher の対称拡張

`PostToolUse` を `Edit|Write` → `Edit|Write|MultiEdit` に拡張する際、
Codex 再レビューで **`PostToolUseFailure` matcher が対称更新されて
いない** 点を指摘された。MultiEdit 失敗時に `.harness/state/tool_failures.count`
が増えない非対称を修正（commit 306b23a）。

### 4. `lib_json.sh` のドット区切りパス対応

`post_edit_verify.sh` が `extract_json_field "$payload" "file_path"` で
top-level を見ていたため、Claude Code の実 payload（`tool_input.file_path`
にネスト）で常に空を返していた既存バグを修正。`lib_json.sh` をドット区切
りパス対応に拡張し、caller を `"tool_input.file_path"` に変更。sed フォー
ルバックは leaf key マッチに変更（既存動作互換）。

### 5. `scripts/verify.local.sh` の `HARNESS_VERIFY_MODE` 対応

`docs/quality/quality-gates.md` で文書化された `static|test|all` の
モード分割を、`verify.local.sh` として初めて実装側でも反映。`static` モー
ドは shellcheck / sh -n / jq / check-sync のみ、`test` モードは hook
smoke tests のみ。

## テスト結果

- `tests/test-check-mojibake.sh`: **11/11 PASS**（U+FFFD 検出 / allowlist / jq 欠落 / Edit/Write/MultiEdit payload 抽出）
- リグレッション: `test-ralph-config.sh` (23), `test-ralph-signals.sh` (3), `test-ralph-status.sh` (40) → 全 PASS
- post_edit_verify 挙動スモーク: Edit / Write / MultiEdit 全ペイロードで `edited-files.log` が populate される（P1-P3 検証）
- `pre_bash_guard.sh` 後方互換スモーク（非ドットパス caller）: PASS

合計 **100+ アサーション PASS**、失敗ゼロ。

## リスクと mitigation

| リスク | 影響 | Mitigation |
|---|---|---|
| Claude Code の hook payload スキーマ変更 | hook が no-op 化 | `tests/fixtures/payloads/*.json` が assert するので CI で検知 |
| 既存 U+FFFD 含有ファイルで無限ループ | workflow block | allowlist 機構 + デフォルトで本プラン/レポートを除外 |
| jq 欠落環境 | silent no-op | fail-open-with-warning、marker ファイルで後段可視化 |
| `post_edit_verify.sh` 修正による既存 caller 破壊 | 他 hook の挙動変化 | sed fallback は leaf key マッチに縮退、`pre_bash_guard.sh` スモーク確認済み |
| テンプレと本体のドリフト | scaffold 後の齟齬 | `check-sync.sh` が PR gate として強制、byte-for-byte mirror |

## ロールバック

本 PR を revert するだけで復元可能。新規 state ファイルは
`.harness/state/mojibake-jq-missing` 1 件のみ（暫定マーカー）で削除安全。

**恒久対策への移行トリガー**: Claude Code 公式が Issue #43746 系を修正し、
1 週間手元で無再発を確認できたら本フック一式を撤去。撤去手順は plan の
「Rollout or rollback notes」に記載。

## 既知の未解決事項

- `packs/languages/golang/verify.sh` は `HARNESS_VERIFY_MODE` を尊重し
  ていない（pre-existing、本 PR の non-goal）
- `shellcheck` が dev マシン未インストール、CI ランナーで担保

## 関連

- 記事: https://nyosegawa.com/posts/claude-code-mojibake-workaround/
- Upstream tracker: GitHub Issue #43746 （想定）
- Tech-debt entry: `docs/tech-debt/README.md`
