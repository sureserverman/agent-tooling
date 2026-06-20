# Agent Description — Triggering Reference

How to write a Claude Code agent `description:` field so that auto-dispatch fires reliably, when it fires vs when the user must invoke explicitly, and how to write `<example>` blocks for subtle cases.

## What the description field does

The `description:` field in an agent's frontmatter is the agent's **dispatch trigger**. When the parent model selects an agent to invoke via the Agent tool, it matches the user's intent against each available agent's description. A well-written description ensures the right agent fires on the right request — and not on unrelated ones.

The description is also visible to users in the `/agents` manager and in IDE agent pickers. It must be both machine-matchable (for auto-dispatch) and human-readable (for user selection).

## Rules for trigger-spec descriptions

### 1. Third-person, trigger-spec style

Write as if describing when a third party should use this agent. Never use first-person.

```yaml
# Wrong — first-person breaks matching
description: I audit links in a project and return a list of broken URLs.

# Correct — trigger-spec, third-person
description: Use when asked to audit links in a project. Triggers on "check links", "find broken URLs", "link audit", or any request to verify that URLs in source files resolve.
```

### 2. Lead with `Use when` or `Triggers on`

The opening clause tells the dispatch model the primary activation condition. Follow with a `Triggers on` list of literal trigger phrases the user might type.

```yaml
description: Use when generating a mock HTTP server from a spec or HAR file. Triggers on "generate mock server", "stub this API", "create a mock for", "mock server from HAR", or any request to produce a runnable stub service.
```

### 3. Trigger phrases should be quoted literals

Quote the exact phrases a user is likely to type. This is not documentation — it is a matching surface. Unquoted phrases blend into the prose and are harder for the dispatch model to weight.

### 4. Stay under 1024 characters

The description field has a hard limit of 1024 characters. Beyond that the runtime truncates it, which can break triggering. Check with:

```bash
echo -n "your description here" | wc -c
```

### 5. Leak-safe phrasing

Do not name internal implementation details, secret file paths, API keys, or internal capability flags in the description. The description is surfaced in the IDE and the `/agents` manager — treat it as public.

## When auto-dispatch fires vs when the user must invoke explicitly

### Auto-dispatch fires when:

- The parent model is deciding which sub-agent to delegate to.
- The user's message matches the trigger phrases or semantic intent in the description.
- The parent has been given the Agent tool and the current context makes agent delegation appropriate.

### Auto-dispatch does NOT fire when:

- The user addresses the parent model directly and asks it to do the work inline.
- The trigger match is ambiguous between two agents with overlapping descriptions.
- The parent model is in a context where it has decided to handle the task itself.

### Explicit invocation

Users can bypass auto-dispatch and invoke an agent directly:

- Name it in the prompt: "use the link-checker agent on docs/".
- Run it as the main session: `claude --agent link-checker` — if the agent
  declares `initialPrompt`, that text is auto-submitted as the first turn.
- Wrap it in a skill/slash command that dispatches the agent internally.

(`/agents` manages and inspects agents; it is not the invocation path.)

When triggers are subtle or the agent name is not obvious from the task, add explicit invocation instructions in the agent body (not the description — the body is the system prompt the agent sees, not the dispatch signal).

## Writing `<example>` blocks

Add `<example>` blocks in the **agent body** (the system prompt section below the frontmatter) when:

- The trigger condition is non-obvious (the agent handles a specialized edge case).
- Multiple agents could plausibly match the same request and you need to disambiguate.
- The output format needs an example to be unambiguous.

### Format

```xml
<example>
User: "Can you check whether all the links in the docs/ directory are still live?"
Action: Read each Markdown file in docs/, extract href and src values, HEAD-request each URL, return a table of status codes.
</example>

<example>
User: "Link audit on the README"
Action: Read README.md, extract all URLs, return a two-column table: URL | status.
</example>
```

### What examples are NOT for

- Do not put examples in the `description:` field — they consume the 1024-char budget without improving machine matching.
- Do not fabricate examples that don't reflect the agent's actual behavior — they will mislead the dispatch model and users.

## Overlap and disambiguation

When two agents in the same plugin could plausibly match the same trigger:

1. Make each `description:` **exclusive** rather than **inclusive**: describe what this agent does that the other one does not.
2. Add a disambiguation note at the end of each description:

```yaml
# link-checker
description: Use when auditing URLs in source files for liveness. Triggers on "check links", "find broken URLs", "link audit". Does NOT generate or modify files — read-only audit only.

# link-fixer
description: Use when broken links have been identified and need to be replaced or removed. Triggers on "fix broken links", "update URLs", "replace dead link". Requires a prior link-checker run or an explicit list of broken URLs.
```

## Checklist before shipping a description

- [ ] Third-person, not first-person
- [ ] Starts with `Use when` or `Triggers on`
- [ ] Trigger phrases are quoted literals
- [ ] Under 1024 characters (`echo -n "..." | wc -c`)
- [ ] No internal implementation details leaked
- [ ] Disambiguated from any overlapping agent in the same plugin
- [ ] Tested by reading it aloud: does it describe when to use this agent, not what the agent does internally?

## Sources

- https://code.claude.com/docs/en/sub-agents (verified 2026-06-09 against Claude Code v2.1.170)
- https://github.com/wshobson/agents (184 community agents — read descriptions for patterns)
