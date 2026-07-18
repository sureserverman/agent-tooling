#!/usr/bin/env bash
# curator-archive.sh <snapshot|archive|restore|list> [slug] [options]
# The curator's ONLY mutating script. It moves skills; it never removes them.
# The worst case for any skill is a move into the archive, fully reversible.
#
#   snapshot            tar.gz the whole skills root into <archive>/snapshots/
#   archive  <slug>     move <skills-root>/<slug>/ -> <archive>/<slug>/
#   restore  <slug>     move <archive>/<slug>/ -> <skills-root>/<slug>/
#   list                list currently archived skills
#
# Options:
#   --skills-root <dir>  default ~/.claude/skills
#   --archive <dir>      default <skills-root>/.archive
#   --label <name>       snapshot filename label (default: UTC timestamp)
#
# There is deliberately no "delete" or "purge" verb: recovery is always one
# `restore` (or an untar of a snapshot) away.
set -eu

ROOT="$HOME/.claude/skills"; ARCHIVE=""; LABEL=""
CMD="${1:-}"; shift || true
SLUG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skills-root) ROOT="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) SLUG="$1"; shift ;;
  esac
done
[ -n "$ARCHIVE" ] || ARCHIVE="$ROOT/.archive"
SNAPDIR="$ARCHIVE/snapshots"

need_slug() { [ -n "$SLUG" ] || { echo "error: '$CMD' needs a skill slug" >&2; exit 2; }; }

case "$CMD" in
  snapshot)
    mkdir -p "$SNAPDIR"
    [ -n "$LABEL" ] || LABEL="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT="$SNAPDIR/snapshot-$LABEL.tar.gz"
    # Archive the whole skills root EXCEPT the archive dir itself (no nesting).
    tar -czf "$OUT" -C "$ROOT" --exclude=".archive" . 2>/dev/null
    echo "$OUT"
    ;;
  archive)
    need_slug
    SRC="$ROOT/$SLUG"
    [ -d "$SRC" ] || { echo "error: no such skill to archive: $SLUG (looked in $ROOT)" >&2; exit 1; }
    DEST="$ARCHIVE/$SLUG"
    [ -e "$DEST" ] && { echo "error: already archived: $SLUG" >&2; exit 1; }
    mkdir -p "$ARCHIVE"
    mv "$SRC" "$DEST"
    echo "archived: $SLUG -> $DEST"
    ;;
  restore)
    need_slug
    SRC="$ARCHIVE/$SLUG"
    [ -d "$SRC" ] || { echo "error: not archived: $SLUG (looked in $ARCHIVE)" >&2; exit 1; }
    DEST="$ROOT/$SLUG"
    [ -e "$DEST" ] && { echo "error: a live skill already occupies $DEST — will not overwrite" >&2; exit 1; }
    mv "$SRC" "$DEST"
    echo "restored: $SLUG -> $DEST"
    ;;
  list)
    if [ -d "$ARCHIVE" ]; then
      find "$ARCHIVE" -mindepth 1 -maxdepth 1 -type d -not -name snapshots -printf '%f\n' 2>/dev/null | sort || true
    fi
    ;;
  *)
    echo "usage: $0 <snapshot|archive|restore|list> [slug] [--skills-root d] [--archive d] [--label l]" >&2
    exit 2 ;;
esac
