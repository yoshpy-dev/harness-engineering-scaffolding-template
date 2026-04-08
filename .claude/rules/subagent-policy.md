# Subagent Delegation Policy

Single source of truth for when to delegate work to subagents.

## Post-implementation pipeline — always delegate

After implementation completes (`/work` or `/loop`), run the post-implementation pipeline via subagents:

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 1 | `reviewer` | `/self-review` | Diff quality |
| 2 | `verifier` | `/verify` | Spec compliance + static analysis |
| 3 | `tester` | `/test` | Behavioral tests |

Each step runs sequentially (output of one informs the next). Use the Task tool with `subagent_type` matching the agent name.

### Execution

```
Task(subagent_type="reviewer", prompt="Run /self-review for the current diff against plan <slug>")
  → reviewer produces docs/reports/self-review-*.md
  → if CRITICAL findings: stop and fix before continuing

Task(subagent_type="verifier", prompt="Run /verify against plan <slug>")
  → verifier produces docs/reports/verify-*.md
  → if fail verdict: stop and fix before continuing

Task(subagent_type="tester", prompt="Run /test against plan <slug>")
  → tester produces docs/reports/test-*.md
  → if fail verdict: do NOT proceed to /pr
```

### Fallback

If a subagent fails to execute (tool error, not a review finding), run the corresponding skill inline and note the fallback in the report.

## Other subagents

| Subagent | Trigger |
|----------|---------|
| `planner` | When `/plan` benefits from context isolation (large codebases, deep research). Optional — inline is also acceptable. |
| `doc-maintainer` | When `/sync-docs` is invoked and context is already crowded. Optional — inline is also acceptable. |

## Rationale

- Post-implementation steps produce independent artifacts with clear boundaries — ideal for subagent isolation.
- Subagent execution preserves main context tokens for implementation work.
- Sequential execution ensures each step can react to prior findings.
