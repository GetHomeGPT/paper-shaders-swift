#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
golden_dir="${1:-"$repo_root/../paper-shaders-prd/golden"}"
output="${2:-"$repo_root/docs/assets/showcase-grid.jpg"}"

shader_names=(
  simplex-noise
  dot-orbit
  mesh-gradient
  waves
  dot-grid
  spiral
  swirl
  neuro-noise
  static-mesh-gradient
  static-radial-gradient
  perlin-noise
  color-panels
  dithering
  god-rays
  voronoi
  smoke-ring
  warp
  metaballs
  pulsing-border
  halftone-cmyk
  paper-texture
  grain-gradient
  water
  fluted-glass
  gem-smoke
  halftone-dots
  heatmap
  image-dithering
  liquid-metal
)

if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick 'magick' is required" >&2
  exit 1
fi

files=()
for name in "${shader_names[@]}"; do
  file="$golden_dir/$name--default.png"
  if [[ ! -f "$file" ]]; then
    echo "error: missing golden render: $file" >&2
    exit 1
  fi
  files+=("$file")
done
files+=("${files[0]}")

mkdir -p "$(dirname "$output")"

magick montage "${files[@]}" \
  -thumbnail 256x256^ \
  -gravity center \
  -extent 256x256 \
  -background '#0d0d0f' \
  -geometry 256x256+16+16 \
  -quality 88 \
  -tile 6x5 \
  "$output"

echo "wrote $output"
