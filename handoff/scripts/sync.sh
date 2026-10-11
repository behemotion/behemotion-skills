#!/usr/bin/env bash
# Generate HANDOFF.md in every repo listed in the source repo's Repository map,
# and install the canonical agent workflow skills from beheskills.
#
# Usage (run from — or pass — the repo that OWNS the map, e.g. the umbrella):
#   bash <beheskills>/handoff/scripts/sync.sh [SOURCE_REPO] [--dry-run]
#
# For each slug in SOURCE_REPO/HANDOFF.md "## Repository map" (first cell in
# backticks), the target is resolved by probing, first hit wins:
#   SOURCE/<slug> (child) · SOURCE/../<slug> (sibling) · SOURCE itself is skipped.
# Each target receives:
#   - HANDOFF.md  = HANDOFF.template.md with <SELF_SLUG> = slug and
#                   <REPO_MAP_ROWS> = the source map's rows (identical everywhere)
#   - docs/handoffs/self/ (created if missing)
#   - .claude/skills/{handoff,land-clean,deploy}/ from beheskills (and the same
#     under .opencode/skills/ when the target has .opencode/). A skill whose
#     SKILL.md contains "beheskills: local" is repo-specific and never touched.
# The source repo gets the skill copies too, but its own HANDOFF.md is left alone.

set -euo pipefail

SKILLS=(handoff land-clean deploy)

script_dir="$(cd "$(dirname "$0")" && pwd)"
beheskills="$(cd "$script_dir/../.." && pwd)"
template="$beheskills/handoff/HANDOFF.template.md"

dry_run=0
src_repo=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    *) src_repo="$arg" ;;
  esac
done
src_repo="$(cd "${src_repo:-$PWD}" && pwd)"
handoff_md="$src_repo/HANDOFF.md"

[ -f "$template" ]   || { echo "ERROR: $template not found" >&2; exit 1; }
[ -f "$handoff_md" ] || { echo "ERROR: $handoff_md not found. Run /handoff init first." >&2; exit 1; }
for s in "${SKILLS[@]}"; do
  [ -f "$beheskills/$s/SKILL.md" ] || { echo "ERROR: canonical $beheskills/$s/SKILL.md missing" >&2; exit 1; }
done

self_slug="$(basename "$src_repo")"

# Map rows, verbatim, from the source's Repository map.
rows_file="$(mktemp)"
trap 'rm -f "$rows_file"' EXIT
awk '
  /^## Repository map/ {in_map=1; next}
  in_map && /^## / {in_map=0}
  in_map && /^[|][[:space:]]*`[^`]+`/ {print}
' "$handoff_md" > "$rows_file"

slugs=()
while IFS= read -r slug; do slugs+=("$slug"); done < <(
  sed -E 's/^[|][[:space:]]*`([^`]+)`.*/\1/' "$rows_file"
)
[ ${#slugs[@]} -gt 0 ] || { echo "No rows in Repository map — nothing to do."; exit 0; }

run() { if [ $dry_run -eq 1 ]; then echo "    (dry-run) $*"; else "$@"; fi; }

install_skills() {  # $1 = repo dir
  local repo="$1" root s dst
  for root in .claude/skills .opencode/skills; do
    [ "$root" = .opencode/skills ] && [ ! -d "$repo/.opencode" ] && continue
    for s in "${SKILLS[@]}"; do
      dst="$repo/$root/$s"
      if [ -f "$dst/SKILL.md" ] && grep -q 'beheskills: local' "$dst/SKILL.md"; then
        echo "    keep  $root/$s (repo-specific)"
        continue
      fi
      run mkdir -p "$dst"
      run rsync -a --delete --exclude='.DS_Store' "$beheskills/$s/" "$dst/"
      echo "    skill $root/$s"
    done
  done
}

echo "Source:     $src_repo (slug: $self_slug)"
echo "beheskills: $beheskills"
echo "Repos:      ${slugs[*]}"
echo

synced=0
for slug in "${slugs[@]}"; do
  if [ "$slug" = "$self_slug" ]; then
    echo "  = $slug (source — skills only)"
    install_skills "$src_repo"
    continue
  fi
  target=""
  if [ -d "$src_repo/$slug" ]; then target="$src_repo/$slug"
  elif [ -d "$src_repo/../$slug" ]; then target="$(cd "$src_repo/../$slug" && pwd)"
  fi
  if [ -z "$target" ]; then echo "  SKIP $slug (not found as child or sibling)"; continue; fi

  echo "  → $slug ($target)"
  if [ $dry_run -eq 0 ]; then
    awk -v slug="$slug" -v rows="$rows_file" '
      /^<REPO_MAP_ROWS>$/ { while ((getline line < rows) > 0) print line; close(rows); next }
      { gsub(/<SELF_SLUG>/, slug); print }
    ' "$template" > "$target/HANDOFF.md"
    mkdir -p "$target/docs/handoffs/self"
  fi
  echo "    HANDOFF.md (${#slugs[@]} rows)"
  install_skills "$target"
  synced=$((synced + 1))
done

echo
echo "Done. Generated HANDOFF.md in $synced repo(s)."
