#!/usr/bin/env bash
# validate-openclaw-artifact.sh <artifact-dir> [--json]
# Deterministic checks for an OpenClaw-BOUND artifact directory — a plugin,
# skills tree, hooks tree, or config drop (June 2026 facts, verified 2026-06-09
# against docs.openclaw.ai tools/skills + tools/creating-skills + tools/plugin +
# plugins/building-plugins + automation + gateway/configuration, OpenClaw
# 2026.6.5). Emits the shared JSON contract.
#
# Checks:
#   - every openclaw.plugin.json parses and has an id; its sibling package.json
#     exists and carries the openclaw field (dual-manifest requirement); every
#     package.json openclaw.extensions path resolves
#   - *.ts imports of the exact root barrel "openclaw/plugin-sdk" (DEPRECATED —
#     use focused subpaths) → warning
#   - every */SKILL.md has closed frontmatter with non-empty name + description;
#     a frontmatter `metadata:` value, if present, must be SINGLE-LINE JSON
#     parseable by jq (the signature OpenClaw check — nested YAML is wrong)
#   - every directory containing HOOK.md also contains handler.ts; HOOK.md
#     frontmatter parses and metadata.openclaw.events is a non-empty list
#     (legacy metadata.clawdbot.events accepted)
#   - every openclaw.json passes a JSON5-ish parse (python3: //-comments and
#     trailing commas stripped best-effort; degrades to a warning without
#     python3)
#
# Scan exclusions: .git/, node_modules/, and tests/fixtures/ (test data) are
# pruned from every scan so self-scans stay clean.
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

prune_find() { # <name-pattern> — find files, skipping .git/node_modules/tests/fixtures
  find "$ROOT" \( -path "$ROOT/.git" -o -name node_modules -o -path "*/tests/fixtures" \) -prune \
    -o -name "$1" -type f -print 2>/dev/null
}

# metadata_line <file> — print the single-line value of a frontmatter `metadata:`
# key ("" if absent). Multi-line YAML under `metadata:` yields "" too — exactly
# the broken case the caller must flag.
metadata_line() {
  extract_frontmatter "$1" | grep '^metadata:' | head -1 | sed 's/^metadata:[[:space:]]*//' || true
}

# --- 1. dual manifests: openclaw.plugin.json + package.json openclaw field ----
while IFS= read -r man; do
  [ -n "$man" ] || continue
  rel="${man#"$ROOT"/}"
  pdir="$(dirname "$man")"
  if ! jq empty "$man" >/dev/null 2>&1; then
    add_finding error openclaw-plugin-manifest openclaw-artifact "$rel" 0 \
      "openclaw.plugin.json is not valid JSON"
  elif [ -z "$(jq -r '.id // empty' "$man")" ]; then
    add_finding error openclaw-plugin-manifest openclaw-artifact "$rel" 0 \
      "openclaw.plugin.json has no id — required (keys plugins.entries/allow/deny/slots)"
  fi
  pkg="$pdir/package.json"
  pkgrel="${pkg#"$ROOT"/}"
  if [ ! -f "$pkg" ]; then
    add_finding error openclaw-package-field openclaw-artifact "$pkgrel" 0 \
      "no package.json next to openclaw.plugin.json — OpenClaw plugins require BOTH manifests"
  elif ! jq -e '.openclaw' "$pkg" >/dev/null 2>&1; then
    add_finding error openclaw-package-field openclaw-artifact "$pkgrel" 0 \
      "package.json has no openclaw field — OpenClaw plugins require BOTH manifests (openclaw.extensions + compat.pluginApi)"
  else
    while IFS= read -r ext; do
      [ -n "$ext" ] || continue
      if [ ! -e "$pdir/${ext#./}" ]; then
        add_finding error openclaw-extensions-missing openclaw-artifact "$pkgrel" 0 \
          "openclaw.extensions entry '$ext' does not resolve to an existing path"
      fi
    done < <(jq -r '.openclaw.extensions[]? // empty' "$pkg")
  fi
done < <(prune_find openclaw.plugin.json)

# --- 2. deprecated root-barrel SDK imports in *.ts -----------------------------
while IFS= read -r ts; do
  [ -n "$ts" ] || continue
  rel="${ts#"$ROOT"/}"
  while IFS=: read -r line _; do
    [ -n "$line" ] || continue
    add_finding warn openclaw-sdk-root-barrel openclaw-artifact "$rel" "$line" \
      "imports the DEPRECATED root barrel 'openclaw/plugin-sdk' — use a focused subpath (e.g. openclaw/plugin-sdk/plugin-entry) and pin compat.pluginApi"
  done < <(grep -nE "['\"]openclaw/plugin-sdk['\"]" "$ts" 2>/dev/null || true)
done < <(prune_find "*.ts")

# --- 3. skills: SKILL.md frontmatter + single-line metadata JSON ---------------
while IFS= read -r sk; do
  [ -n "$sk" ] || continue
  rel="${sk#"$ROOT"/}"
  if ! has_closing_fence "$sk"; then
    add_finding error openclaw-skill-frontmatter openclaw-artifact "$rel" 1 \
      "SKILL.md has no closed YAML frontmatter block (--- … ---)"
    continue
  fi
  missing=""
  [ -n "$(frontmatter_field "$sk" name)" ] || missing="name"
  [ -n "$(frontmatter_field "$sk" description)" ] || missing="${missing:+$missing,}description"
  [ -z "$missing" ] || add_finding error openclaw-skill-frontmatter openclaw-artifact "$rel" 1 \
    "SKILL.md frontmatter missing required field(s): $missing"
  if extract_frontmatter "$sk" | grep -q '^metadata:'; then
    meta="$(metadata_line "$sk")"
    if [ -z "$meta" ] || ! printf '%s' "$meta" | jq empty >/dev/null 2>&1; then
      add_finding error openclaw-skill-metadata-json openclaw-artifact "$rel" 0 \
        "frontmatter metadata must be SINGLE-LINE JSON (jq-parseable) — a nested YAML block is not read by OpenClaw"
    fi
  fi
done < <(prune_find SKILL.md)

# --- 4. hooks: HOOK.md needs handler.ts + non-empty events ---------------------
while IFS= read -r hk; do
  [ -n "$hk" ] || continue
  rel="${hk#"$ROOT"/}"
  hdir="$(dirname "$hk")"
  hrel="${hdir#"$ROOT"/}"
  [ -f "$hdir/handler.ts" ] || add_finding error openclaw-hook-handler-missing openclaw-artifact "$hrel" 0 \
    "hook directory has HOOK.md but no handler.ts — OpenClaw hooks are HOOK.md + handler.ts (default-export async handler)"
  if ! has_closing_fence "$hk"; then
    add_finding error openclaw-hook-events openclaw-artifact "$rel" 1 \
      "HOOK.md has no closed YAML frontmatter block (--- … ---)"
    continue
  fi
  meta="$(metadata_line "$hk")"
  if [ -z "$meta" ] || ! printf '%s' "$meta" | jq empty >/dev/null 2>&1; then
    add_finding error openclaw-hook-events openclaw-artifact "$rel" 0 \
      "HOOK.md frontmatter metadata must be single-line JSON carrying openclaw.events"
  elif ! printf '%s' "$meta" | jq -e '(.openclaw.events // .clawdbot.events) | type=="array" and length>0' >/dev/null 2>&1; then
    add_finding error openclaw-hook-events openclaw-artifact "$rel" 0 \
      "metadata.openclaw.events must be a non-empty list (e.g. [\"command:new\"]) — without it the hook never fires"
  fi
done < <(prune_find HOOK.md)

# --- 5. openclaw.json: JSON5-ish parse -----------------------------------------
if command -v python3 >/dev/null 2>&1; then
  while IFS= read -r cfg; do
    [ -n "$cfg" ] || continue
    rel="${cfg#"$ROOT"/}"
    out=$(python3 - "$cfg" <<'PYEOF' 2>/dev/null || echo "internal-error"
import json, re, sys
src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
try:
    import json5  # full JSON5 when available
    json5.loads(src)
    print("ok"); sys.exit(0)
except ImportError:
    pass
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120]); sys.exit(0)
# best-effort JSON5-ish: strip //-comments (not inside strings) + trailing commas
out_chars, in_str, esc, i = [], False, False, 0
while i < len(src):
    c = src[i]
    if in_str:
        out_chars.append(c)
        if esc:
            esc = False
        elif c == "\\":
            esc = True
        elif c == '"':
            in_str = False
        i += 1
        continue
    if c == '"':
        in_str = True; out_chars.append(c); i += 1; continue
    if c == "/" and src[i:i+2] == "//":
        j = src.find("\n", i)
        i = len(src) if j == -1 else j
        continue
    out_chars.append(c); i += 1
stripped = re.sub(r",(\s*[}\]])", r"\1", "".join(out_chars))
try:
    json.loads(stripped)
    print("ok")
except Exception as e:
    print("parse:" + str(e).replace("\n", " ")[:120])
PYEOF
)
    case "$out" in
      ok) : ;;
      parse:*)
        add_finding error openclaw-config-parse openclaw-artifact "$rel" 0 \
          "openclaw.json fails a JSON5-ish parse (//-comments and trailing commas stripped): ${out#parse:} — the Gateway will not start on a broken config" ;;
      *)
        add_finding error openclaw-config-parse openclaw-artifact "$rel" 0 \
          "openclaw.json parse check failed to run" ;;
    esac
  done < <(prune_find openclaw.json)
else
  add_finding warn openclaw-python-missing openclaw-artifact "." 0 \
    "python3 not found — openclaw.json JSON5 parse check skipped"
fi

render_findings "validate-openclaw-artifact.sh" "$ROOT"; exit $?
