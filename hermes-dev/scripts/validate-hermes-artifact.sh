#!/usr/bin/env bash
# validate-hermes-artifact.sh <artifact-dir> [--json]
# Deterministic checks for a Hermes-Agent-BOUND artifact directory — a Hermes
# Python plugin, skills tree, or config drop (June 2026 facts, verified
# 2026-06-09 against hermes-agent.nousresearch.com/docs +
# github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
# Release"). Emits the shared JSON contract.
#
# Hermes ships multiple minor releases per month (v0.14→v0.16 within May–June
# 2026) — when upstream changes the manifest or frontmatter rules, update the
# checks here and scripts/README.md together.
#
# Checks:
#   - every plugin.yaml parses (python3 + pyyaml), has name + version +
#     description, provides_tools/provides_hooks (if present) are YAML lists,
#     and a sibling __init__.py exists and contains "def register("
#   - every skills */SKILL.md has closed YAML frontmatter with name +
#     description; a missing version is a WARNING (Hermes requires version,
#     other agentskills.io hosts don't — ports routinely miss it);
#     metadata.hermes (if present) must be a mapping
#   - every config.yaml parses; each mcp_servers entry has command or url
#   - every *.py compiles (python3 -m py_compile)
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# pruned from all scans so self-scans stay clean.
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

PY=0; PYYAML=0
if command -v python3 >/dev/null 2>&1; then
  PY=1
  python3 -c 'import yaml' >/dev/null 2>&1 && PYYAML=1
fi
[ "$PY" = 1 ] || add_finding warn hermes-python-missing hermes-artifact "." 0 \
  "python3 not found — YAML and py_compile checks skipped"
[ "$PY" = 1 ] && [ "$PYYAML" = 0 ] && add_finding warn hermes-python-missing hermes-artifact "." 0 \
  "pyyaml not installed — YAML checks skipped (pip install pyyaml)"

prune_find() { # <name-pattern> — find files, skipping .git/node_modules/tests/fixtures
  find "$ROOT" \( -path "$ROOT/.git" -o -name node_modules -o -path "*/tests/fixtures" \) -prune \
    -o -name "$1" -type f -print 2>/dev/null
}

# --- 1. plugin.yaml: parse + fields + types + sibling register(ctx) ------------
if [ "$PYYAML" = 1 ]; then
  while IFS= read -r py; do
    [ -n "$py" ] || continue
    rel="${py#"$ROOT"/}"
    out=$(python3 - "$py" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys, yaml
try:
    data = yaml.safe_load(open(sys.argv[1], encoding="utf-8", errors="replace"))
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120]); sys.exit(0)
if not isinstance(data, dict):
    print("parse:top level is not a mapping"); sys.exit(0)
missing = [k for k in ("name", "version", "description")
           if not isinstance(data.get(k), str) or not str(data[k]).strip()]
if missing:
    print("fields:" + ",".join(missing))
badtypes = [k for k in ("provides_tools", "provides_hooks")
            if k in data and not isinstance(data[k], list)]
if badtypes:
    print("types:" + ",".join(badtypes))
print("done")
PYEOF
)
    while IFS= read -r line; do
      case "$line" in
        done) : ;;
        parse:*)
          add_finding error hermes-plugin-yaml-parse hermes-artifact "$rel" 0 \
            "plugin.yaml does not parse as YAML: ${line#parse:}" ;;
        fields:*)
          add_finding error hermes-plugin-yaml-fields hermes-artifact "$rel" 0 \
            "plugin.yaml missing required field(s): ${line#fields:} (name, version, description are all required)" ;;
        types:*)
          add_finding error hermes-plugin-yaml-types hermes-artifact "$rel" 0 \
            "${line#types:} must be YAML list(s), not scalar(s) — Hermes refuses comma-joined strings" ;;
        *)
          add_finding error hermes-plugin-yaml-parse hermes-artifact "$rel" 0 \
            "plugin.yaml check failed to run" ;;
      esac
    done <<< "$out"

    # sibling __init__.py with register(ctx)
    init="$(dirname "$py")/__init__.py"
    relinit="${init#"$ROOT"/}"
    if [ ! -f "$init" ]; then
      add_finding error hermes-plugin-register-missing hermes-artifact "$relinit" 0 \
        "plugin has no __init__.py next to plugin.yaml — Hermes plugins are Python packages with def register(ctx)"
    elif ! grep -q 'def register(' "$init"; then
      add_finding error hermes-plugin-register-missing hermes-artifact "$relinit" 0 \
        "__init__.py has no 'def register(' — the package is silently not a plugin without register(ctx)"
    fi
  done < <(prune_find plugin.yaml)
fi

# --- 2. skills */SKILL.md frontmatter -------------------------------------------
if [ "$PYYAML" = 1 ]; then
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    rel="${s#"$ROOT"/}"
    out=$(python3 - "$s" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys, yaml
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
if not lines or lines[0].strip() != "---":
    print("no-frontmatter"); sys.exit(0)
end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
if end is None:
    print("no-frontmatter"); sys.exit(0)
try:
    data = yaml.safe_load("\n".join(lines[1:end])) or {}
except Exception:
    print("bad-yaml"); sys.exit(0)
if not isinstance(data, dict):
    print("bad-yaml"); sys.exit(0)
missing = [k for k in ("name", "description")
           if not isinstance(data.get(k), str) or not data[k].strip()]
if missing:
    print("missing:" + ",".join(missing))
v = data.get("version")
if not (isinstance(v, (str, int, float)) and str(v).strip()):
    print("no-version")
md = data.get("metadata")
if md is not None:
    h = md.get("hermes") if isinstance(md, dict) else None
    if (not isinstance(md, dict)) or ("hermes" in md and not isinstance(h, dict)):
        print("bad-metadata")
print("done")
PYEOF
)
    while IFS= read -r line; do
      case "$line" in
        done) : ;;
        no-frontmatter)
          add_finding error hermes-skill-frontmatter hermes-artifact "$rel" 1 \
            "SKILL.md has no closed YAML frontmatter block (--- … ---)" ;;
        bad-yaml)
          add_finding error hermes-skill-frontmatter hermes-artifact "$rel" 1 \
            "SKILL.md frontmatter is not valid YAML" ;;
        missing:*)
          add_finding error hermes-skill-frontmatter hermes-artifact "$rel" 1 \
            "SKILL.md frontmatter missing required field(s): ${line#missing:}" ;;
        no-version)
          add_finding warn hermes-skill-no-version hermes-artifact "$rel" 1 \
            "frontmatter has no version — Hermes requires it (other agentskills.io hosts don't); update/skill_manage flows depend on it" ;;
        bad-metadata)
          add_finding error hermes-skill-metadata hermes-artifact "$rel" 1 \
            "metadata.hermes must be a mapping (tags/category/config) — got a non-mapping value" ;;
        *)
          add_finding error hermes-skill-frontmatter hermes-artifact "$rel" 0 \
            "frontmatter check failed to run" ;;
      esac
    done <<< "$out"
  done < <(prune_find SKILL.md)
fi

# --- 3. config.yaml: parse + mcp_servers entries ---------------------------------
if [ "$PYYAML" = 1 ]; then
  while IFS= read -r cfg; do
    [ -n "$cfg" ] || continue
    rel="${cfg#"$ROOT"/}"
    out=$(python3 - "$cfg" <<'PYEOF' 2>/dev/null || echo "internal-error"
import sys, yaml
try:
    data = yaml.safe_load(open(sys.argv[1], encoding="utf-8", errors="replace"))
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120]); sys.exit(0)
if data is None:
    data = {}
if not isinstance(data, dict):
    print("parse:top level is not a mapping"); sys.exit(0)
mcp = data.get("mcp_servers")
if isinstance(mcp, dict):
    for name, entry in mcp.items():
        if not isinstance(entry, dict) or not any(
                isinstance(entry.get(k), str) and entry[k].strip()
                for k in ("command", "url")):
            print("mcp:" + str(name))
print("done")
PYEOF
)
    while IFS= read -r line; do
      case "$line" in
        done) : ;;
        parse:*)
          add_finding error hermes-config-parse hermes-artifact "$rel" 0 \
            "config.yaml does not parse as YAML: ${line#parse:}" ;;
        mcp:*)
          add_finding error hermes-config-mcp hermes-artifact "$rel" 0 \
            "mcp_servers entry '${line#mcp:}' has neither command (stdio) nor url (HTTP) — dead config, Hermes can't start it" ;;
        *)
          add_finding error hermes-config-parse hermes-artifact "$rel" 0 \
            "config.yaml check failed to run" ;;
      esac
    done <<< "$out"
  done < <(prune_find config.yaml)
fi

# --- 4. *.py: syntax (py_compile) -------------------------------------------------
if [ "$PY" = 1 ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$ROOT"/}"
    # PYTHONPYCACHEPREFIX keeps py_compile's bytecode out of the artifact tree
    if ! PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/hermes-dev-pyc" python3 -m py_compile "$f" >/dev/null 2>&1; then
      add_finding error hermes-plugin-py-syntax hermes-artifact "$rel" 0 \
        "Python file does not compile (python3 -m py_compile) — the plugin will fail to load"
    fi
  done < <(prune_find '*.py')
fi

render_findings "validate-hermes-artifact.sh" "$ROOT"; exit $?
