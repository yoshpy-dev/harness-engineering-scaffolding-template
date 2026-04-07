# __TITLE__

- Status: Draft
- Owner: Claude Code
- Date: __DATE__
- Related request: __REQUEST__
- Related issue: __ISSUE__
- Branch: TBD (one per slice)

## Objective

## Scope

## Non-goals

## Assumptions

## Affected areas

## Acceptance criteria

- [ ]

## Slice decomposition

<!-- Each slice runs as an independent Ralph Loop in its own Git Worktree. -->
<!-- Slices MUST NOT share mutable files. Define clear file ownership. -->

| Slice | Description | Files owned | Depends on | Size | Task type |
|-------|-------------|-------------|------------|------|-----------|
| | | | (none) | S/M/L | general |

### Dependency graph

<!-- Use ASCII or describe the DAG. Independent slices run in parallel. -->
<!-- Example: [shared-types] → [auth-api, dashboard] → [e2e-tests] -->

### Shared interfaces

<!-- List any contracts (types, schemas, API signatures) that must be defined -->
<!-- before parallel slices can begin. These are implemented first, sequentially. -->

## Implementation outline

1. Define shared interfaces (sequential)
2. Run parallel slices
3. Sequential merge and integration verification

## Verify plan

- Static analysis checks:
- Spec compliance criteria to confirm:
- Documentation drift to check:
- Evidence to capture:
- Merge conflict check: run after each slice merge

## Test plan

- Unit tests: per slice
- Integration tests: after all slices merged
- Regression tests:
- Edge cases:
- Evidence to capture:

## Risks and mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Merge conflicts between slices | Medium | Medium | Clear file ownership, sequential merge |

## Merge strategy

- Merge slices one at a time into main
- After each merge, rebase remaining slice branches onto updated main
- Run integration tests after each merge
- If a merge produces conflicts, resolve manually before continuing

## Rollout or rollback notes

## Open questions

## Progress checklist

- [ ] Plan reviewed
- [ ] Shared interfaces defined
- [ ] Worktrees created
- [ ] All slices complete
- [ ] Sequential merge complete
- [ ] Integration tests pass
- [ ] PR created
