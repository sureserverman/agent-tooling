# Hook Development Utility Scripts

## Validating hooks — use the canonical suite

Structural validation of `hooks.json` and bundled hook scripts (event names,
hook types, `${CLAUDE_PLUGIN_ROOT}` usage, Stop-guard, timeouts) is deterministic
and lives in the plugin's shared validation suite — **not here**. The old
`validate-hook-schema.sh` and `hook-linter.sh` were merged into it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-hooks.sh" path/to/hooks.json
# or, as part of a full plugin check:
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-plugin.sh" <plugin-root>
```

See `scripts/README.md` at the plugin root for the determinism boundary and the
JSON finding contract. That suite carries the current 2026 event list as its
single source of truth.

## test-hook.sh — run a hook against sample input

This is a **test harness**, not a validator: it actually executes a hook script
with a JSON event on stdin and interprets the result. It stays here because
running a hook is behavioral, not a static check.

**Usage:**
```bash
./test-hook.sh [options] <hook-script> <test-input.json>
```

**Options:**
- `-v, --verbose` — show detailed execution information
- `-t, --timeout N` — set timeout in seconds (default: 60)
- `--create-sample <event-type>` — generate sample test input

**Example:**
```bash
# Create sample test input, then run the hook against it
./test-hook.sh --create-sample PreToolUse > test-input.json
./test-hook.sh -v my-hook.sh test-input.json
```

**Features:**
- Sets up CLAUDE_PROJECT_DIR / CLAUDE_PLUGIN_ROOT
- Measures execution time, validates output JSON
- Shows exit codes and their meanings (0 = allow, 2 = block)

## Typical workflow

1. Write the hook script (or scaffold one: `scripts/scaffold-hook.sh <root> <event>`).
2. **Test behavior:** `./test-hook.sh -v my-hook.sh test-input.json`
3. **Validate structure:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-hooks.sh" hooks/hooks.json`
4. Try it live: `claude --debug`

## Common issues

- **Hook doesn't execute** — missing shebang, not `chmod +x`, or path not using `${CLAUDE_PLUGIN_ROOT}`.
- **Hook times out** — lower the timeout or remove long-running work.
- **Fails silently** — check exit codes (0 or 2) and send errors to stderr (`>&2`).
- **Injection risk** — always quote variables (`"$var"`), `set -euo pipefail`, validate input. `validate-hooks.sh` flags the structural cases.
