#!/bin/bash
# Renders every ported preset offscreen and compares against the workbench
# goldens with the upstream perceptual comparator (pixelmatch).
#
# Usage:
#   Scripts/check-parity.sh
#   WORKBENCH=../paper-shaders-prd FAIL_RATIO=0.01 Scripts/check-parity.sh
set -euo pipefail
cd "$(dirname "$0")/.."

WORKBENCH="${WORKBENCH:-../paper-shaders-prd}"
FAIL_RATIO="${FAIL_RATIO:-0.01}"
OUT="${PARITY_OUT:-.build/parity-output}"

allowed_fail_ratio() {
  case "$1" in
    # These presets depend on screen-space derivatives whose exact
    # neighborhood differs between the SwiftShader WebGL goldens and Metal.
    # The shaders use a deterministic Metal mask pass; see docs/DERIVATIVE-PARITY.md.
    grain-gradient--blob.png) echo "0.03" ;;
    grain-gradient--default.png) echo "0.02" ;;
    grain-gradient--dots.png) echo "0.10" ;;
    grain-gradient--ripple.png) echo "0.06" ;;
    grain-gradient--truchet.png) echo "0.09" ;;
    grain-gradient--wave.png) echo "0.11" ;;
    halftone-cmyk--default.png) echo "0.17" ;;
    halftone-cmyk--drops.png) echo "0.04" ;;
    halftone-cmyk--vintage.png) echo "0.13" ;;
    halftone-dots--default.png) echo "0.05" ;;
    # High-amplitude fract(sin(dot())) noise differs between SwiftShader
    # WebGL goldens and Metal; see docs/GOLDEN-PARITY.md.
    heatmap--sepia.png) echo "0.27" ;;
    *) echo "$FAIL_RATIO" ;;
  esac
}

if [[ ! -d "$WORKBENCH/golden" ]]; then
  echo "error: goldens not found at $WORKBENCH/golden (set WORKBENCH)" >&2
  exit 2
fi

echo "Rendering presets to $OUT ..."
PARITY_OUT="$OUT" swift test --filter GoldenRenderTests >/dev/null

pass=0
fail=0
for png in "$OUT"/*.png; do
  name="$(basename "$png")"
  [[ "$name" == *-diff.png ]] && continue
  golden="$WORKBENCH/golden/$name"
  if [[ ! -f "$golden" ]]; then
    echo "MISS  $name (no golden)"
    fail=$((fail + 1))
    continue
  fi
  ratio="$(allowed_fail_ratio "$name")"
  if result=$(bun "$WORKBENCH/tools/compare-images.ts" "$golden" "$png" \
      --fail-ratio "$ratio" --out "$OUT/${name%.png}-diff.png" 2>&1); then
    echo "PASS  $name  ${result#PASS: }"
    pass=$((pass + 1))
  else
    echo "FAIL  $name  ${result#FAIL: }"
    fail=$((fail + 1))
  fi
done

echo
echo "parity: $pass passed, $fail failed (default fail-ratio $FAIL_RATIO)"
[[ "$fail" -eq 0 ]]
