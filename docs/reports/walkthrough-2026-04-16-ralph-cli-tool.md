# Walkthrough: ralph CLI ツール化

## 概要

テンプレートリポジトリを `ralph` CLI ツールに変換。120ファイル、+6700行の大規模変更。

## アーキテクチャ

```
cmd/ralph/main.go          ← エントリポイント（cobra + go:embed）
    ↓
internal/cli/              ← サブコマンド群
    ├── init.go            ← ralph init（huh インタラクティブ）
    ├── upgrade.go         ← ralph upgrade（diff + コンフリクト解決）
    ├── run.go             ← ralph run（Phase 6a: シェルラッパー）
    ├── doctor.go          ← ralph doctor（5点環境チェック）
    ├── pack.go            ← ralph pack add/list
    ├── status.go          ← ralph status（TUI統合）
    └── ...
    ↓
internal/scaffold/         ← テンプレートエンジン
    ├── embed.go           ← go:embed FS（templates/ → fs.FS）
    ├── manifest.go        ← .ralph/manifest.toml 管理
    └── render.go          ← ファイル展開 + SHA256 ハッシュ
    ↓
internal/upgrade/          ← アップグレードエンジン
    └── diff.go            ← ハッシュベース差分（auto/conflict/add/remove）
    ↓
internal/config/           ← ralph.toml パーサー
internal/prompt/           ← プロンプト解決（ローカル → 内蔵フォールバック）
```

## 主要な設計判断

1. **go:embed でテンプレート埋め込み**: ルートの `templates.go` に `embed.FS` を配置（go:embed はパッケージディレクトリ内のファイルのみ参照可能なため）。`scaffold.EmbeddedFS` は `fs.FS` インターフェースとして宣言し、テスト時に `fstest.MapFS` で差し替え可能。

2. **Phase 6a ラッパーファースト**: パイプライン（run/retry/abort）は既存シェルスクリプトを `os/exec` でラップ。TOML 設定を環境変数に変換して渡す。Go ネイティブ移植は Phase 6b（別PR）で実施。

3. **再 init → upgrade 委譲**: マニフェストが存在する場合の `ralph init` は `runUpgrade` に委譲し、ユーザー編集済みファイルを保護。

4. **upgrade skip 時の OldHash 保持**: skip 選択時にディスクハッシュではなく旧テンプレートハッシュを保持し、次回 upgrade でも正しくコンフリクト検出。

## Codex レビュー対応

6件の指摘に対して ACTION_REQUIRED 3件 + WORTH_CONSIDERING 2件を修正、DISMISSED 1件。
