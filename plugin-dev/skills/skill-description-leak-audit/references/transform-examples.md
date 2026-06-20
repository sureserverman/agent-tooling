# Transform Examples — Leaky → Clean Descriptions

Before/after pairs for common leak patterns. Use these as templates when rewriting a leaky description in Step 5.

## Example 1 — testing skill

Before:
```yaml
description: Comprehensive testing workflow with parallel unit/integration tests and gated E2E coverage reporting
```

After:
```yaml
description: Use when the user says "run tests", "test this", "check test coverage", or asks to verify code before shipping
```

## Example 2 — debug skill

Before:
```yaml
description: Bug investigation and resolution workflow that traces stack frames, reproduces locally, writes a failing test, then fixes and verifies
```

After:
```yaml
description: Use when the user says "fix this bug", "debug this", "this is broken", "why does X fail", or reports unexpected behavior in code
```

## Example 3 — review skill

Before:
```yaml
description: Multi-stage code review that scans diffs, runs linters, checks coverage, and posts inline comments
```

After:
```yaml
description: Use when the user says "review this code", "check my PR", "code review", or asks for feedback on changes before merging
```

## What stays out of the "after" versions

Any mention of steps, tools, stages, or outputs. Only the *situations* that should trigger the skill remain. If you catch yourself writing a verb that describes internal behaviour ("parses", "aggregates", "reports"), stop — that belongs in the body.
