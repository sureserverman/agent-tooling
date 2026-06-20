#!/usr/bin/env bash
# validate-mcp.sh <.mcp.json | plugin-root> [--json]
# Deterministic checks for a bundled MCP config: parse, transport type, required
# per-transport fields, ${CLAUDE_PLUGIN_ROOT} for bundled servers, plaintext
# secrets in env.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
TARGET="${ARGS[0]:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <.mcp.json|plugin-root> [--json]" >&2; exit 2; }

if [ -d "$TARGET" ]; then MCP="$TARGET/.mcp.json"; else MCP="$TARGET"; fi
REL="$MCP"

if [ ! -f "$MCP" ]; then
  add_finding error mcp-missing mcp "$REL" 0 ".mcp.json not found"
  render_findings "validate-mcp.sh" "$TARGET"; exit $?
fi
if ! jq empty "$MCP" >/dev/null 2>&1; then
  add_finding error mcp-unparseable mcp "$REL" 0 ".mcp.json is not valid JSON"
  render_findings "validate-mcp.sh" "$TARGET"; exit $?
fi

names=$(jq -r '(.mcpServers // .) | keys[]?' "$MCP")
if [ -z "$names" ]; then
  add_finding warn mcp-no-servers mcp "$REL" 0 ".mcp.json declares no servers"
fi

while IFS= read -r srv; do
  [ -n "$srv" ] || continue
  obj=$(jq -c --arg s "$srv" '(.mcpServers // .)[$s]' "$MCP")
  type=$(printf '%s' "$obj" | jq -r '.type // empty')
  command=$(printf '%s' "$obj" | jq -r '.command // empty')
  url=$(printf '%s' "$obj" | jq -r '.url // empty')

  if [ -z "$type" ]; then
    add_finding warn mcp-no-type mcp "$REL" 0 "[$srv] no 'type' — declare one of stdio|sse|http|ws"
    [ -n "$command" ] && type=stdio
    [ -n "$url" ] && type=http
  else
    case "$type" in stdio|sse|http|ws) ;; *) add_finding error mcp-type-unknown mcp "$REL" 0 "[$srv] type '$type' not in {stdio,sse,http,ws}" ;; esac
  fi

  case "$type" in
    stdio)
      if [ -z "$command" ]; then
        add_finding error mcp-no-command mcp "$REL" 0 "[$srv] stdio server has no 'command'"
      elif printf '%s' "$command" | grep -Eq '/|\.(sh|py|js|ts)$'; then
        if printf '%s' "$command" | grep -Eq '^(/home/|/Users/|\./)' && ! printf '%s' "$command" | grep -q '${CLAUDE_PLUGIN_ROOT}'; then
          add_finding error mcp-path-not-root mcp "$REL" 0 "[$srv] bundled server path is absolute/relative — reference it via \${CLAUDE_PLUGIN_ROOT}"
        fi
      fi
      ;;
    sse|http|ws)
      [ -n "$url" ] || add_finding error mcp-no-url mcp "$REL" 0 "[$srv] remote ($type) server has no 'url'"
      ;;
  esac

  # plaintext secrets in env
  while IFS=$'\t' read -r k v; do
    [ -n "$k" ] || continue
    case "$v" in *'${'*) continue ;; esac
    if printf '%s' "$k" | grep -Eiq 'token|secret|password|api[_-]?key|access[_-]?key' \
       || printf '%s' "$v" | grep -Eq '^(sk-|ghp_|gho_|github_pat_|AKIA|xox[bap]-)'; then
      add_finding warn mcp-plaintext-secret mcp "$REL" 0 "[$srv] env '$k' looks like a plaintext secret — use \${ENV_VAR} expansion, not a literal"
    fi
  done < <(printf '%s' "$obj" | jq -r '(.env // {}) | to_entries[]? | [.key, (.value|tostring)] | @tsv')
done <<< "$names"

render_findings "validate-mcp.sh" "$TARGET"; exit $?
