#!/usr/bin/env bash
# validate-agent.sh <path-to-agent.md> [--json]
# Deterministic checks for a subagent definition. Supersedes the old
# skills/agent-development/scripts/validate-agent.sh, which wrongly *required*
# <example> blocks + "Use this agent when…" + a color field — patterns the
# plugin's own leak-audit guidance flags. Those checks are gone; description
# quality is now a leak *candidate* check the LLM lane confirms.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
AGENT="${ARGS[0]:-}"
[ -n "$AGENT" ] || { echo "usage: $0 <agent.md> [--json]" >&2; exit 2; }
REL="$AGENT"

if [ ! -f "$AGENT" ]; then
  add_finding error agent-missing agent "$REL" 0 "agent file not found"
  render_findings "validate-agent.sh" "$AGENT"; exit $?
fi
if ! has_closing_fence "$AGENT"; then
  add_finding error agent-no-frontmatter agent "$REL" 1 "agent must open and close a YAML frontmatter block (---)"
  render_findings "validate-agent.sh" "$AGENT"; exit $?
fi

NAME=$(frontmatter_field "$AGENT" name)
DESC=$(frontmatter_field "$AGENT" description)
MODEL=$(frontmatter_field "$AGENT" model)
COLOR=$(frontmatter_field "$AGENT" color)
VERSION=$(frontmatter_field "$AGENT" version)
DESC_LINE=$(grep -n '^description:' "$AGENT" | head -1 | cut -d: -f1); DESC_LINE=${DESC_LINE:-0}

[ -n "$NAME" ] || add_finding error agent-no-name agent "$REL" 0 "frontmatter missing required field: name"
[ -n "$DESC" ] || add_finding error agent-no-description agent "$REL" 0 "frontmatter missing required field: description"

if [ -n "$NAME" ]; then
  base=$(basename "$AGENT" .md)
  [ "$NAME" = "$base" ] \
    || add_finding error agent-name-mismatch agent "$REL" 0 "name '$NAME' must match the file name '$base.md'"
  printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || add_finding warn agent-name-not-kebab agent "$REL" 0 "name '$NAME' is not kebab-case"
fi

if [ -z "$MODEL" ]; then
  add_finding warn agent-no-model agent "$REL" 0 "no model pinned — set one (haiku for read-only, sonnet for write-capable, or inherit)"
else
  case "$MODEL" in
    inherit|haiku|sonnet|opus|claude-*) ;;
    *) add_finding warn agent-model-unknown agent "$REL" 0 "model '$MODEL' not in {inherit,haiku,sonnet,opus,claude-*}" ;;
  esac
fi

if [ -n "$COLOR" ]; then
  case "$COLOR" in
    red|orange|yellow|green|cyan|blue|purple|magenta|pink) ;;
    *) add_finding warn agent-color-unknown agent "$REL" 0 "color '$COLOR' is not a standard terminal color" ;;
  esac
fi

[ -z "$VERSION" ] || add_finding info agent-has-version agent "$REL" 0 "agents do not take a version field (it is ignored) — remove it"

# tools: light touch. Don't whitelist (MCP names + Bash(jq:*) syntax vary) — but
# a bare '*' should be a deliberate choice worth surfacing.
TOOLS=$(frontmatter_field "$AGENT" tools)
if printf '%s' "$TOOLS" | grep -Eq '(^|[][ ",])\*([][ ",]|$)'; then
  add_finding info agent-tools-wildcard agent "$REL" 0 "tools includes '*' (all tools) — confirm the agent truly needs full access"
fi

# system prompt = body after the frontmatter
BODY=$(awk '/^---[[:space:]]*$/{i++; next} i>=2' "$AGENT")
blen=${#BODY}
if [ "$blen" -lt 20 ]; then
  add_finding error agent-no-body agent "$REL" 0 "system prompt (body after frontmatter) is empty or too short"
fi

[ -z "$DESC" ] || check_description "$REL" "$DESC_LINE" agent "$DESC"

render_findings "validate-agent.sh" "$AGENT"; exit $?
