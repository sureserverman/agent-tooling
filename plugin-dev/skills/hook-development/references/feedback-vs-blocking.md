# Feedback Injection vs. Blocking in PostToolUse Hooks

## The core question

When a `PostToolUse` hook detects a problem (lint error, type error, test failure), should it:

- **Block** — prevent the tool result from being accepted, forcing a retry?
- **Inject feedback** — accept the tool result and return the error as `additionalContext` for the next turn?

**Default answer: inject feedback.**

---

## Why blocking PostToolUse usually causes more harm than good

Blocking in `PostToolUse` means the tool call is retroactively treated as failed. From the
user's perspective the write never happened, but the file on disk may already be partially
modified. The model sees a failure with no guidance and will typically retry the same operation,
creating a loop.

Concrete problems:

1. **Silent data loss.** The write is rolled back or never acknowledged, but the model's
   context says it succeeded. The mismatch is invisible until the user checks the file.

2. **Retry thrash.** Without a signal explaining *why* the block occurred, the model generates
   the same or a minimally different output and hits the same block again.

3. **User surprise.** The user issued an instruction. The hook silently refused to honor it.
   No error appears in the UI. The session stalls.

4. **Conflation of concerns.** A linter error is not a tool failure. The file was written
   correctly — the content just needs improvement. Blocking confuses the transport layer
   (tool execution) with the content layer (code quality).

---

## Why feedback injection works better

Returning errors as `additionalContext` lets the model self-correct within its own
reasoning loop — the mechanism it is designed to use.

Benefits:

- The write completes. The file is never in an ambiguous state.
- The model receives structured feedback and typically fixes the error on the next turn
  without another user prompt.
- The user sees progress, not a silent stall.
- The hook stays simple: run the checker, return output, exit.

---

## Before / after comparison

### Before — blocking hook (fragile)

```bash
#!/usr/bin/env bash
# BAD: blocks the write if eslint finds any errors
FILE=$(jq -r '.output.path // empty' <<<"$1")
if ! eslint "$FILE" > /dev/null 2>&1; then
  # The write is blocked. The model has no idea why.
  exit 1
fi
```

What happens:
1. Model writes a file with a lint error.
2. Hook blocks. From the model's perspective, the Edit tool failed.
3. Model retries the same content. Hook blocks again.
4. Session stalls. User sees nothing in the UI.

### After — feedback injection (robust)

```bash
#!/usr/bin/env bash
# GOOD: accepts the write, surfaces lint errors as context
FILE=$(jq -r '.output.path // empty' <<<"$1")
[ -z "$FILE" ] && exit 0
RESULT=$(eslint --format=compact "$FILE" 2>&1 || true)
[ -z "$RESULT" ] && exit 0
jq -n --arg ctx "eslint found issues — please fix before proceeding:\n$RESULT" \
   '{"additionalContext": $ctx}'
```

What happens:
1. Model writes a file with a lint error.
2. Hook runs eslint, returns errors as `additionalContext`.
3. On the next turn the model sees the errors in context and rewrites the file.
4. Session makes progress. No user intervention needed.

---

## When blocking IS appropriate

Blocking is the right choice in `PostToolUse` only when:

- The tool's side-effect is **irreversible** and the damage exceeds the cost of stalling.
  Example: a hook that intercepts a deploy command and blocks it if the target environment
  is production and no approval token is present.

- The check is a **hard gate**, not a quality signal. Example: a license-header check that
  is a legal requirement, not a style preference.

In these cases, return a clear `reason` so the model (and user) can act:

```bash
jq -n '{"block": true, "reason": "Missing required license header. Add SPDX-License-Identifier before proceeding."}'
```

---

## Decision rule summary

| Situation | Use |
|---|---|
| Lint / type errors / style issues | Feedback injection (`additionalContext`) |
| Test failures on non-critical paths | Feedback injection |
| Security scan warning | Feedback injection (block only for critical severity) |
| Missing required header / legal gate | Block with `reason` |
| Irreversible side-effect (deploy, publish) | Block with `reason` |
| Tool produced malformed output | Block with `reason` |
