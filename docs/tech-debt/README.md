# Tech debt

Record debt that should not disappear into chat history.

Recommended fields:
- debt item
- impact
- why it was deferred
- trigger for paying it down
- related plan or report

## Entries

| Debt item | Impact | Why deferred | Trigger to pay down | Related plan/report |
| --- | --- | --- | --- | --- |
| CLAUDE.md line 14 の "proceed through /self-review, /verify, /test" がsubagent委譲を明示していない。line 21 の新ポリシーと表面上矛盾する。 | 新規読者が line 14 と line 21 を別フローと解釈するリスク | 今回のスコープはline 21のみ変更。line 14の修正は計画の非ゴール | CLAUDE.md 次回編集時、または混乱報告が発生したとき | docs/reports/self-review-2026-04-08-subagent-trigger-policy.md |
| `ralph-orchestrator.sh` の pipe-subshell 変数スコープバグ 3箇所: 依存関係チェック (line 473)、統合マージチェック (line 343)、abort ワークツリーリスト (scripts/ralph:294)。POSIX sh では `cmd \| while` がサブシェルで実行されるため、ループ内の変数変更が親シェルに伝播しない。 | HIGH: 並列スライスが依存関係を無視して起動する; マージコンフリクトが検出されず無視される | v2パイプライン初回リリースのスコープ外; オーケストレータ統合テストが未実装 | 並列オーケストレータを実際に使用するとき、またはオーケストレータ統合テスト追加時 | docs/reports/self-review-2026-04-09-ralph-loop-v2.md |
| `ralph-pipeline.sh` の CRITICAL self-review 発見を無視するポリシー (line 421: "Don't stop — let verify and test catch real issues") が AGENTS.md および subagent-policy.md の契約と矛盾する。意図的な逸脱だが計画に記載がない。 | MEDIUM: セキュリティや正確性の問題でパイプラインが継続する可能性 | パイプライン自律性を優先; CRITICAL発見すべてで停止するのは過剰保守的と判断 | 実運用でCRITICAL発見クラスが明確になったとき、またはセキュリティインシデント発生時 | docs/reports/self-review-2026-04-09-ralph-loop-v2.md |
