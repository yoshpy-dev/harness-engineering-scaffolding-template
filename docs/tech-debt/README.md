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
| `orchestrator.tmp.json` in `cleanup_on_exit` not PID-suffixed | Potential race between cleanup trap and normal exit path writing the same temp file on SIGINT during final jq call | Low probability in practice (trap fires after `main()` returns); normal path already uses `.$$.json` suffix | If `orchestrator.json` corruption is observed after interrupt | `docs/reports/self-review-2026-04-15-ralph-pipeline-hardening.md` |
| Per-slice pipelines do NOT stop on CRITICAL self-review findings | Differs from standard `/work` flow behavior | Autonomous pipelines benefit from letting verify/test confirm true positives before halting | If false-negative CRITICAL findings slip through to merge | `.claude/rules/post-implementation-pipeline.md` |
