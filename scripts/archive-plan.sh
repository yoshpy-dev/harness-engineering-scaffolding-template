#!/usr/bin/env sh
set -eu

usage() {
  echo "Usage: ./scripts/archive-plan.sh <plan-file-or-slug>"
  echo ""
  echo "Move an active plan to the archive."
  echo "Accepts a full path, a filename, or a slug (matched against docs/plans/active/)."
  exit 1
}

if [ "${1:-}" = "" ]; then
  usage
fi

arg="$1"
src=""

if [ -f "$arg" ]; then
  src="$arg"
elif [ -f "docs/plans/active/$arg" ]; then
  src="docs/plans/active/$arg"
else
  match="$(find docs/plans/active -maxdepth 1 -type f -name "*${arg}*" 2>/dev/null | head -n 1)"
  if [ -n "$match" ]; then
    src="$match"
  fi
fi

if [ -z "$src" ]; then
  echo "No matching active plan found for: $arg"
  echo ""
  echo "Active plans:"
  find docs/plans/active -maxdepth 1 -type f -name '*.md' 2>/dev/null || echo "  (none)"
  exit 1
fi

mkdir -p docs/plans/archive
filename="$(basename "$src")"
dest="docs/plans/archive/$filename"

if [ -f "$dest" ]; then
  echo "Archive already contains $filename. Aborting to avoid overwrite."
  exit 1
fi

mv "$src" "$dest"
echo "Archived: $src -> $dest"
