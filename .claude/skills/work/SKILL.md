---
name: work
description: Execute an approved plan in small coherent slices, updating progress, evidence, and docs as implementation evolves.
disable-model-invocation: true
---
Work from the active plan, not from memory alone.

## Steps

1. Read the current active plan in `docs/plans/active/`.
2. Confirm acceptance criteria and verification strategy before editing code.
3. Implement in small slices that can be reviewed and verified independently.
4. Update the plan's progress checklist while working.
5. If the task splits cleanly, delegate focused research or review to subagents.
6. If repeated failures occur, reduce scope, inspect evidence, and revise the plan instead of thrashing.
7. Keep docs, contracts, and tests aligned with behavior changes.
8. Before presenting completion, run `/review` and `/verify` or equivalent deterministic checks.
9. After all acceptance criteria are met and verification passes, archive the plan with `./scripts/archive-plan.sh <slug>`.

## Completion gate

Do NOT present a task as complete unless ALL of the following are true:

- [ ] `./scripts/run-verify.sh` exits 0 (or a project-specific verifier passes)
- [ ] A verify report exists in `docs/reports/`
- [ ] Raw evidence is saved in `docs/evidence/`
- [ ] A review report exists in `docs/reports/` (or was explicitly deemed unnecessary for docs-only changes)
- [ ] The active plan's progress checklist is fully updated
- [ ] Any discovered tech debt is recorded in `docs/tech-debt/`

If verification has not run, say so explicitly instead of claiming done.

## Anti-bottleneck

Before asking the user for confirmation, next steps, or choices, first check whether you can resolve the question through verification, repo context, subagents, or reasonable defaults. See the `anti-bottleneck` skill for the full checklist.

## Strong defaults

- One slice at a time
- Evidence before confidence
- Versioned plan over chat-only plan
- Smaller diffs over heroic rewrites
