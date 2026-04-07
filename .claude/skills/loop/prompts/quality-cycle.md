<!-- Quality cycle contract — included by all task-type prompts. -->
<!-- This section replaces the simple "verify the change works" step with a full -->
<!-- implement → self-review → verify → test cycle within each iteration. -->

## Quality cycle

After implementing your change, complete ALL four phases before committing.
Record each phase result in progress.log. If any phase fails, do NOT commit —
fix the issue in the SAME iteration if small, or note it and move to the next
iteration for a targeted fix.

### Phase 1: Implement
- Apply the change described in your iteration step.
- Keep the diff small and focused.

### Phase 2: Self-review
- Read your own diff (`git diff`).
- Check for: naming issues, unnecessary changes, debug code, hardcoded secrets,
  null safety gaps, typos, security risks (injection, XSS, path traversal).
- If you find issues, fix them before proceeding.

### Phase 3: Verify
- Run `./scripts/run-static-verify.sh` (linters, type checks).
- Walk through each acceptance criterion from the plan and confirm whether
  your change advances it.
- If static analysis fails, fix and re-run.

### Phase 4: Test
- Run `./scripts/run-test.sh` (unit, integration tests).
- If tests fail, fix the cause and re-run.
- If tests do not exist for your change, write at least one covering the
  happy path and one edge case before proceeding.

### Phase result format

Append phase results to the iteration summary in progress.log:

```
## Iteration N — <timestamp>
- What: <what was done>
- Implement: pass
- Self-review: pass (fixed: <brief note> / clean)
- Verify: pass/fail (<details if fail>)
- Test: pass/fail (<details if fail>)
- Result: <pass if all four pass, fail otherwise>
- Next: <what the next iteration should do>
```

### Completion gate

You may output `<promise>COMPLETE</promise>` ONLY when ALL of the following are true:
1. All acceptance criteria from the plan or objective are met
2. Self-review found no remaining issues
3. `./scripts/run-static-verify.sh` passes
4. `./scripts/run-test.sh` passes
5. progress.log shows the final iteration with all four phases passing

### Quality cycle state

Read `.harness/state/loop/phase-state.json` at the start of each iteration
to understand the previous iteration's phase results. Update it at the end
of each iteration with your results.
