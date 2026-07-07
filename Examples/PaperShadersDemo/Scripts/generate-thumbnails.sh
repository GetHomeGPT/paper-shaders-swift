#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
example_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$example_dir/../.." && pwd)"
workbench="${WORKBENCH:-"$repo_root/../paper-shaders-prd"}"
source_dir="$workbench/golden"
output_dir="$example_dir/Sources/PaperShadersDemo/Resources/Thumbnails"
size="${THUMBNAIL_SIZE:-192}"

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required to generate thumbnails on macOS" >&2
  exit 1
fi

mkdir -p "$output_dir"
rm -f "$output_dir"/*.png

count=0
for source in "$source_dir"/*--default.png; do
  [[ -e "$source" ]] || continue
  file_name="$(basename "$source")"
  shader_name="${file_name%--default.png}"
  sips --resampleHeightWidth "$size" "$size" "$source" --out "$output_dir/$shader_name.png" >/dev/null
  count=$((count + 1))
done

if [[ "$count" -ne 29 ]]; then
  echo "Expected 29 thumbnails, generated $count" >&2
  exit 1
fi

echo "Generated $count Swift demo thumbnails in $output_dir"
