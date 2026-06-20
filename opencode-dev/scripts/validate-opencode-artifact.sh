#!/usr/bin/env bash
# validate-opencode-artifact.sh <artifact-dir> [--json]
# Deterministic checks for an OpenCode-BOUND artifact directory (a repo's
# .opencode/ payload, a global config dir, or a plugin/tool bundle) — the
# things OpenCode enforces or silently breaks on (June 2026 facts, verified
# 2026-06-09 against opencode.ai/docs/agents, /docs/commands, /docs/plugins,
# /docs/config, /docs/skills; OpenCode v1.16). Emits the shared JSON contract.
#
# Checks:
#   - agents/*.md and commands/*.md (also legacy singular agent/, command/):
#     YAML frontmatter parses (python3 + pyyaml); agent frontmatter using the
#     deprecated `tools:` boolean map → warn (migrate to `permission`)
#   - legacy singular component dirs (agent/ command/ plugin/ tool/ skill/
#     theme/ at the artifact root or under .opencode/) → warn — plural is
#     canonical; singular has silent-ignore bug history (issue #14410)
#   - opencode.json / opencode.jsonc: parses (// comments stripped
#     best-effort for .jsonc); unknown top-level keys vs the known set → warn;
#     deprecated `autoshare` → warn (use `share`)
#   - plugins/*.js: `node --check`; plugins/*.{js,ts}: must be non-empty and
#     contain an `export` — a plugin without exports silently never loads
#   - skills/*/SKILL.md: `name` (regex ^[a-z0-9]+(-[a-z0-9]+)*$, 1-64 chars)
#     and `description` present
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# skipped by every recursive scan.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/findings.sh"
have_jq

JSON=0; ARGS=()
for a in "$@"; do case "$a" in --json) JSON=1 ;; *) ARGS+=("$a") ;; esac; done
[ "$JSON" = 1 ] && export FINDINGS_JSON=1
ROOT="${ARGS[0]:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "usage: $0 <artifact-dir> [--json]" >&2; exit 2; }

# prune expression shared by every recursive scan
scan() { # <extra find args…>
  find "$ROOT" \( -name .git -o -name node_modules -o -path "*/tests/fixtures" \) -prune -o "$@" -print 2>/dev/null
}

# --- Known opencode.json top-level keys (v1.16) ---------------------------------
# autoshare is "known" so it gets exactly one finding (the deprecation warn),
# not two.
KNOWN_KEYS='["$schema","model","small_model","provider","agent","command",
"permission","tools","mcp","plugin","instructions","formatter","lsp","shell",
"server","share","snapshot","autoupdate","autoshare","theme","keybinds",
"username","disabled_providers","experimental"]'

# --- 1. agents/ + commands/ frontmatter ------------------------------------------
# fm_check <file>: prints OK | TOOLS | BROKEN <reason>
fm_check() {
  python3 - "$1" <<'PY'
import sys, yaml
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
lines = text.split("\n")
if not lines or lines[0].strip() != "---":
    print("BROKEN no frontmatter fence"); sys.exit(0)
try:
    end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
except StopIteration:
    print("BROKEN unclosed frontmatter fence"); sys.exit(0)
try:
    fm = yaml.safe_load("\n".join(lines[1:end]))
except yaml.YAMLError as e:
    print("BROKEN " + str(e).split("\n")[0]); sys.exit(0)
fm = fm or {}
if not isinstance(fm, dict):
    print("BROKEN frontmatter is not a YAML mapping"); sys.exit(0)
if "tools" in fm:
    print("TOOLS"); sys.exit(0)
print("OK")
PY
}

check_md() { # <file> <kind: agent|command>
  local f="$1" kind="$2" rel res
  rel="${f#"$ROOT"/}"
  res=$(fm_check "$f" 2>/dev/null || echo "BROKEN python3/pyyaml unavailable or crashed")
  case "$res" in
    OK) ;;
    TOOLS)
      if [ "$kind" = agent ]; then
        add_finding warn opencode-tools-deprecated opencode-artifact "$rel" 0 \
          "agent frontmatter uses the deprecated 'tools:' boolean map — migrate to 'permission' (ask/allow/deny per key, bash glob maps)"
      fi ;;
    BROKEN*)
      add_finding error opencode-frontmatter opencode-artifact "$rel" 0 \
        "unparseable $kind YAML frontmatter — ${res#BROKEN }" ;;
  esac
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    */agents/*|*/agent/*) check_md "$f" agent ;;
    *)                    check_md "$f" command ;;
  esac
done < <(scan -type f \( -path "*/agents/*.md" -o -path "*/agent/*.md" \
                      -o -path "*/commands/*.md" -o -path "*/command/*.md" \))

# --- 2. legacy singular component dirs -------------------------------------------
# Plural is canonical (agents/ commands/ plugins/ tools/ skills/ themes/);
# singular dirs at the artifact root or under a .opencode/ dir have a
# silent-ignore bug history (issue #14410).
for s in agent command plugin tool skill theme; do
  for d in "$ROOT/$s" "$ROOT/.opencode/$s"; do
    [ -d "$d" ] || continue
    rel="${d#"$ROOT"/}"
    add_finding warn opencode-singular-dir opencode-artifact "$rel" 0 \
      "legacy singular '$s/' directory — canonical is '${s}s/'; singular spellings have silent-ignore bug history (issue #14410)"
  done
done

# --- 3. opencode.json / opencode.jsonc -------------------------------------------
# parse_config <file>: prints KEYS <json-array> | BROKEN <reason>
parse_config() {
  python3 - "$1" <<'PY'
import sys, json
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()

def strip_comments(s):  # best-effort // stripper that respects strings
    out, i, in_str, esc = [], 0, False, False
    while i < len(s):
        c = s[i]
        if in_str:
            out.append(c)
            esc = (c == "\\" and not esc)
            if c == '"' and not esc:
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == "/" and i + 1 < len(s) and s[i+1] == "/":
            while i < len(s) and s[i] != "\n":
                i += 1
            continue
        out.append(c); i += 1
    return "".join(out)

try:
    data = json.loads(text)
except json.JSONDecodeError:
    try:
        data = json.loads(strip_comments(text))
    except json.JSONDecodeError as e:
        print("BROKEN " + str(e)); sys.exit(0)
if not isinstance(data, dict):
    print("BROKEN top level is not a JSON object"); sys.exit(0)
print("KEYS " + json.dumps(sorted(data.keys())))
PY
}

while IFS= read -r cfg; do
  [ -n "$cfg" ] || continue
  rel="${cfg#"$ROOT"/}"
  res=$(parse_config "$cfg" 2>/dev/null || echo "BROKEN python3 unavailable or crashed")
  case "$res" in
    KEYS*)
      keys="${res#KEYS }"
      # deprecated autoshare
      if printf '%s' "$keys" | jq -e 'index("autoshare")' >/dev/null; then
        add_finding warn opencode-autoshare-deprecated opencode-artifact "$rel" 0 \
          "'autoshare' is deprecated — use \"share\": \"manual\"|\"auto\"|\"disabled\""
      fi
      # unknown top-level keys
      while IFS= read -r k; do
        [ -n "$k" ] || continue
        add_finding warn opencode-config-unknown-key opencode-artifact "$rel" 0 \
          "unknown top-level key '$k' — not in the v1.16 config schema; typos are silently ignored by OpenCode"
      done < <(printf '%s' "$keys" | jq -r --argjson known "$KNOWN_KEYS" '.[] | select(. as $k | $known | index($k) | not)')
      ;;
    BROKEN*)
      add_finding error opencode-config-parse opencode-artifact "$rel" 0 \
        "config does not parse as JSON(C) — ${res#BROKEN }" ;;
  esac
done < <(scan -type f \( -name opencode.json -o -name opencode.jsonc \))

# --- 4. plugins/*.{js,ts} ---------------------------------------------------------
while IFS= read -r p; do
  [ -n "$p" ] || continue
  rel="${p#"$ROOT"/}"
  case "$p" in
    *.js)
      if command -v node >/dev/null 2>&1 && ! node --check "$p" >/dev/null 2>&1; then
        add_finding error opencode-plugin-syntax opencode-artifact "$rel" 0 \
          "plugin fails 'node --check' — JavaScript syntax error"
        continue
      fi ;;
  esac
  if [ ! -s "$p" ] || ! grep -q "export" "$p"; then
    add_finding error opencode-plugin-no-export opencode-artifact "$rel" 0 \
      "plugin file has no 'export' — OpenCode plugins must export an async plugin function; this file silently never loads"
  fi
done < <(scan -type f \( -path "*/plugins/*.js" -o -path "*/plugins/*.ts" \
                      -o -path "*/plugin/*.js" -o -path "*/plugin/*.ts" \))

# --- 5. skills/*/SKILL.md ---------------------------------------------------------
while IFS= read -r sk; do
  [ -n "$sk" ] || continue
  rel="${sk#"$ROOT"/}"
  fm_name="$(frontmatter_field "$sk" name)"
  fm_desc="$(frontmatter_field "$sk" description)"
  if [ -z "$fm_name" ] || [ -z "$fm_desc" ]; then
    add_finding error opencode-skill-frontmatter opencode-artifact "$rel" 0 \
      "SKILL.md needs both 'name' and 'description' in frontmatter — without them the skill silently fails to load"
  elif ! printf '%s' "$fm_name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || [ "${#fm_name}" -gt 64 ]; then
    add_finding error opencode-skill-frontmatter opencode-artifact "$rel" 0 \
      "skill name '$fm_name' invalid — must match ^[a-z0-9]+(-[a-z0-9]+)*\$ and be 1-64 chars"
  fi
done < <(scan -type f -path "*/skills/*/SKILL.md")

render_findings "validate-opencode-artifact.sh" "$ROOT"; exit $?
