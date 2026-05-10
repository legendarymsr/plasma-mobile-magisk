#!/usr/bin/env bash
# Packages the Plasma Mobile Magisk module into a flashable zip.
set -euo pipefail

VERSION=$(grep '^version=' module.prop | cut -d= -f2)
OUT="plasma-mobile-${VERSION}.zip"

rm -f "$OUT"

zip -r9 "$OUT" \
  META-INF \
  module.prop \
  customize.sh \
  service.sh \
  action.sh \
  system.prop \
  system

echo "Built: $OUT"
