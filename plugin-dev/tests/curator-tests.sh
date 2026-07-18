#!/usr/bin/env bash
# curator-tests.sh — re-runnable coverage for the read-only curator scan lane.
# Exercises curator-inventory.sh / curator-usage.sh / curator-scan.sh against
# the fixtures under tests/fixtures/curator/. Exit 0 iff every assertion holds.
#
#   bash plugin-dev/tests/curator-tests.sh
set -eu
TDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$TDIR/../scripts"
FX="$TDIR/fixtures/curator"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
# check <label> <jq-filter> <json> — assert filter is true
check() { if printf '%s' "$3" | jq -e "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "curator-inventory:"
INV=$(bash "$S/curator-inventory.sh" "$FX/estate" --json)
check "records carry required keys" 'all(.skills[]; has("path") and has("origin") and has("bytes") and has("mtime"))' "$INV"
check "alpha=personal, beta=plugin" '(.skills[]|select(.name=="alpha").origin)=="personal" and (.skills[]|select(.name=="beta").origin)=="plugin"' "$INV"

echo "curator-usage:"
U=$(bash "$S/curator-usage.sh" --sessions "$FX/sessions" --json alpha beta)
check "alpha max ts + count 2" '(.usage[]|select(.skill=="alpha").last)=="2026-03-15T14:30:00.000Z" and (.usage[]|select(.skill=="alpha").count)==2' "$U"
check "beta no-evidence (not unused)" '(.usage[]|select(.skill=="beta").state)=="no-evidence" and (.usage[]|select(.skill=="beta").last)==null' "$U"
E=$(bash "$S/curator-usage.sh" --sessions "$FX/edge/sessions" --json gamma)
check "malformed+nonZ lines skipped, valid kept, max correct" '(.usage[]|select(.skill=="gamma").count)==2 and (.usage[]|select(.skill=="gamma").last)=="2026-09-09T00:00:00.000Z"' "$E"
EMPTY=$(bash "$S/curator-usage.sh" --sessions /nonexistent-sessions-dir --json alpha)
check "empty history -> history_present false" '.history_present==false' "$EMPTY"

echo "curator-scan:"
SC=$(bash "$S/curator-scan.sh" "$FX/scan/estate" --sessions "$FX/scan/sessions" --pins "$FX/scan/pins" --now 1789000000 --json)
check "45d unused -> stale"                '(.skills[]|select(.name=="stale45").state)=="stale"' "$SC"
check "100d unused -> archive-candidate"   '(.skills[]|select(.name=="arch100").state)=="archive-candidate"' "$SC"
check "pinned 100d -> pinned (not archive)" '(.skills[]|select(.name=="pinned100").state)=="pinned"' "$SC"
check "plugin origin -> report-only"        '(.skills[]|select(.name=="plug100").state)=="report-only"' "$SC"
check "no-evidence -> mtime fallback"       '(.skills[]|select(.name=="mtimefb").basis)=="mtime" and (.skills[]|select(.name=="mtimefb").state)=="archive-candidate"' "$SC"
ES=$(bash "$S/curator-scan.sh" "$FX/edge/estate" --sessions "$FX/edge/sessions" --pins /nonexistent --now 1789000000 --json)
check "absent pins -> no false pinned"      '[.skills[]|select(.state=="pinned")]|length==0' "$ES"
check "space-name stays one skill"          'any(.skills[]; .name=="two words")' "$ES"
E2=$(bash "$S/curator-scan.sh" "$FX/edge2/estate" --sessions "$FX/edge2/sessions" --pins /nonexistent --now 1789000000 --json)
check "unparseable ts -> mtime fallback, not epoch0" '(.skills[]|select(.name=="up").basis)=="usage-unparsed" and (.skills[]|select(.name=="up").age_days)<365' "$E2"

echo "validate-curator:"
VCB=$(bash "$S/validate-curator.sh" "$FX/artifacts-bad" --json 2>/dev/null || true)
check "malformed pins -> version error" '.summary.errors>=1 and any(.findings[]; .rule=="curator-pins-no-version")' "$VCB"
VCG=$(bash "$S/validate-curator.sh" "$FX/artifacts-good" --json 2>/dev/null)
check "well-formed artifacts -> zero findings" '.summary.errors==0 and .summary.warnings==0 and (.findings|length==0)' "$VCG"

echo "curator-archive (round-trip):"
AT="$(mktemp -d)/skills"; mkdir -p "$AT/gamma"; printf -- '---\nname: gamma\ndescription: d\n---\nG\n' > "$AT/gamma/SKILL.md"
cp -r "$AT/gamma" "$AT/../gamma-pristine"
bash "$S/curator-archive.sh" archive gamma --skills-root "$AT" >/dev/null
[ ! -d "$AT/gamma" ] && [ -d "$AT/.archive/gamma" ] && ok "archive moves out of active set" || bad "archive moves out of active set"
bash "$S/curator-archive.sh" restore gamma --skills-root "$AT" >/dev/null
if diff -r "$AT/../gamma-pristine" "$AT/gamma" >/dev/null 2>&1; then ok "restore is byte-identical"; else bad "restore is byte-identical"; fi
if bash "$S/curator-archive.sh" archive nope --skills-root "$AT" >/dev/null 2>&1; then bad "bad slug -> nonzero"; else ok "bad slug -> nonzero"; fi

echo
echo "curator-tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
