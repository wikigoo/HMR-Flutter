#!/usr/bin/env bash
# Generate lib/theme/app_colors.g.dart from the HMR-Design design system
# (single source of truth). Regenerate after any brand/token change:
#
#   bash tool/gen_tokens.sh
#
# CI (.github/workflows/design-tokens-drift.yml) fails if the committed file is
# out of date. Only solid `#rrggbb` hue tokens are generated; app-specific
# composite colors (glass, bubbles) stay hand-authored in app_theme.dart.
set -euo pipefail

SRC="${HMR_DESIGN_COLORS_URL:-https://raw.githubusercontent.com/wikigoo/HMR-Design/main/tokens/colors.css}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/lib/theme/app_colors.g.dart"

css="$(curl -fsSL "$SRC")"

{
  echo "// GENERATED FILE — do not edit by hand."
  echo "// Source of truth: wikigoo/HMR-Design  (tokens/colors.css)"
  echo "// Regenerate:      bash tool/gen_tokens.sh"
  echo "//"
  echo "// Base brand hue tokens, shared with the website (HMR-Astro). App-specific"
  echo "// composites (glass fills, bubble gradients) live in app_theme.dart."
  echo "import 'package:flutter/material.dart';"
  echo ""
  echo "/// Brand color tokens generated from the HMR-Design design system."
  echo "class HmrTokens {"
  echo "  HmrTokens._();"
  printf '%s\n' "$css" \
    | grep -oE -- '--hmr-[a-z0-9-]+:[[:space:]]*#[0-9a-fA-F]{6}' \
    | while IFS= read -r line; do
        name="${line%%:*}"; name="${name#--hmr-}"
        hex="${line##*#}"
        id="$(printf '%s' "$name" | awk -F- '{o=$1; for(i=2;i<=NF;i++){o=o toupper(substr($i,1,1)) substr($i,2)} print o}')"
        HEX="$(printf '%s' "$hex" | tr '[:lower:]' '[:upper:]')"
        echo "  static const Color ${id} = Color(0xFF${HEX});"
      done
  echo "}"
} > "$OUT"

echo "wrote $OUT"
