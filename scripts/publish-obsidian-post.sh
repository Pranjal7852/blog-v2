#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--dry-run] <obsidian-note.md>\n' "${0##*/}"
  printf 'Imports a Markdown note and its local images, builds Hugo, then commits and pushes.\n'
}

dry_run=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi
if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

source_file="$1"
if [[ ! -f "$source_file" || "${source_file##*.}" != "md" ]]; then
  printf 'Error: provide an existing Markdown file ending in .md.\n' >&2
  exit 2
fi
source_file="$(cd "$(dirname "$source_file")" && pwd)/$(basename "$source_file")"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
basename="$(basename "$source_file" .md)"
slug="$(printf '%s' "$basename" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
if [[ -z "$slug" ]]; then
  printf 'Error: could not create a URL slug from the note filename.\n' >&2
  exit 2
fi

target="$repo_root/content/posts/$slug.md"
relative_target="content/posts/$slug.md"
title="${basename//[-_]/ }"
if [[ -e "$target" || -n "$(git -C "$repo_root" status --porcelain -- "$relative_target")" ]]; then
  printf 'Error: %s already exists; refusing to overwrite it.\n' "$relative_target" >&2
  exit 1
fi

created=1
staged=0
manifest="$(mktemp)"
image_paths=()
cleanup() {
  if [[ "$created" == 1 ]]; then
    if [[ "$staged" == 1 ]]; then
      git -C "$repo_root" reset -q -- "$relative_target" "${image_paths[@]}" || true
    fi
    rm -f "$target"
    while IFS= read -r image_path; do
      [[ -n "$image_path" ]] && rm -f "$repo_root/$image_path"
    done < "$manifest"
  fi
  rm -f "$manifest"
}
trap cleanup EXIT

first_line="$(sed -n '1p' "$source_file")"
if [[ "$first_line" == "---" ]]; then
  if grep -Eiq '^draft:[[:space:]]*true([[:space:]]*(#.*)?)?$' "$source_file"; then
    printf 'Error: the note is marked draft: true. Set it to false before publishing.\n' >&2
    exit 1
  fi
  cp "$source_file" "$target"
else
  title="${title//\'/\'\'}"
  {
    printf -- "---\ntitle: '%s'\ndate: %s\ndraft: false\n---\n\n" "$title" "$(date +%F)"
    cat "$source_file"
  } > "$target"
fi

python3 "$repo_root/scripts/import_obsidian_images.py" \
  "$source_file" "$target" "$repo_root" "$slug" "$manifest"
while IFS= read -r image_path; do
  [[ -n "$image_path" ]] && image_paths+=("$image_path")
done < "$manifest"

if grep -Eq '!?\[\[[^]]+\]\]' "$target"; then
  printf 'Warning: Obsidian [[wikilinks]] remain; convert them to standard Markdown links.\n' >&2
fi

cd "$repo_root"
hugo --minify

if [[ "$dry_run" == 1 ]]; then
  printf 'Dry run passed. No Git changes were made.\n'
  exit 0
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  printf 'Error: could not determine the current Git branch.\n' >&2
  exit 1
fi
if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  printf 'Error: configure an upstream branch before publishing.\n' >&2
  exit 1
fi
upstream_branch="${upstream#*/}"
if [[ "$branch" != "$upstream_branch" ]]; then
  printf 'Error: current branch %s does not match upstream branch %s.\n' "$branch" "$upstream_branch" >&2
  exit 1
fi
ahead="$(git rev-list --count "$upstream..HEAD")"
if [[ "$ahead" != 0 ]]; then
  printf 'Error: current branch has %s unpushed commit(s); push or resolve them before importing.\n' "$ahead" >&2
  exit 1
fi

staged=1
git add -- "$relative_target"
if [[ ${#image_paths[@]} -gt 0 ]]; then
  git add -- "${image_paths[@]}"
fi
if [[ ${#image_paths[@]} -gt 0 ]]; then
  git commit --only -m "Publish blog post: $title" -- "$relative_target" "${image_paths[@]}"
else
  git commit --only -m "Publish blog post: $title" -- "$relative_target"
fi
created=0
git push "${upstream%%/*}" "$branch"
printf 'Pushed %s to %s.\n' "$relative_target" "$upstream"