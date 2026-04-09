@AGENTS.md

# Claude Code

Use this file only for Claude-specific guidance that must be always-on.

## Default behavior

- `/plan` is the only manual-trigger skill. All others (work, loop, self-review, verify, test, codex-review, pr, sync-docs, audit-harness) are auto-invoked.
- Use `/plan` before risky, ambiguous, or multi-file work. It does not create a branch — branch/worktree creation is deferred to the chosen flow skill.
- `/plan` asks two decisions: (1) 標準フロー (/work) or Ralph Loop (/loop), (2) Ralph Loop 時は単一プラン or 並列スライスプラン。Follow the user's choice.
- `/work` creates a normal branch (`git checkout -b`) and starts interactive implementation. Post-impl pipeline runs via subagents.
- `/loop` creates a Git Worktree (`git worktree add`) for autonomous iteration. Three modes:
  - **標準ループ** (`ralph-loop.sh`): implementation only. Post-impl pipeline runs via subagents after the loop.
  - **パイプライン** (`ralph-pipeline.sh`): full autonomous Inner/Outer Loop (implement → self-review → verify → test → sync-docs → codex-review → PR).
  - **並列スライス** (`ralph-orchestrator.sh`): directory-based plan → multi-worktree → integration branch → sequential merge → unified PR. Auto-selected when plan is directory-based.
- In pipeline/parallel mode, the scripts handle the full lifecycle autonomously — no manual subagent chain needed. Use `./scripts/ralph run` or `./scripts/ralph status` to operate.
- In standard loop mode or after /work, the post-implementation pipeline runs via subagents (`/self-review` → `/verify` → `/test` → `/sync-docs`), then `/codex-review` (optional, inline), then `/pr`.
- `/self-review` is diff quality only. `/verify` is spec compliance + static analysis. `/test` is behavioral tests. Each produces a separate report.
- Codex advisory is optional. If `codex` CLI is available, `/plan` and `/codex-review` invoke it for second-opinion feedback. If unavailable, the step is silently skipped and the flow continues unchanged.
- Codex findings are presented to the user for judgment — never auto-applied.
- `/pr` creates the pull request, archives the plan, and completes the hand-off. A task is "done" when the PR is created.
- Prefer `.claude/rules/` for topic or path-specific guidance.
- Prefer `.claude/skills/` for workflows and reusable playbooks.
- Post-implementation pipeline (`/self-review` → `/verify` → `/test` → `/sync-docs`) always runs via subagents (`reviewer`, `verifier`, `tester`, `doc-maintainer`). See `.claude/rules/subagent-policy.md` for the full delegation policy.
- Run `./scripts/run-verify.sh` or an equivalent deterministic check before claiming success.
- If context is getting crowded, checkpoint progress in the active plan before compaction.
- Keep this file small; if a rule grows, move it out.

## Claude-specific directories

- `.claude/rules/` for conditional rules
- `.claude/skills/` for on-demand workflows
- `.claude/agents/` for specialized subagents
- `.claude/hooks/` for deterministic runtime controls
