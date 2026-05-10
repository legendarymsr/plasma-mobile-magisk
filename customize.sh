#!/sbin/sh
# Runs inside Magisk's installer during flash (sourced by update-binary).
# Downloads Noto Sans fonts and Plasma Mobile wallpapers.

FONTS_DIR="$MODPATH/system/fonts"
WALLS_DIR="$MODPATH/system/media/wallpapers"

mkdir -p "$FONTS_DIR" "$WALLS_DIR"

try_dl() {
  local url="$1" dest="$2"
  command -v curl >/dev/null 2>&1 && { curl -fsSL -o "$dest" "$url" && return 0; }
  command -v wget >/dev/null 2>&1 && { wget -qO  "$dest" "$url" && return 0; }
  return 1
}

ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
[ -n "$ONEUI_VER" ] && ui_print "- Detected OneUI $ONEUI_VER (Samsung)"

# ── Noto Sans ─────────────────────────────────────────────────────────────────
ui_print "- Downloading Noto Sans fonts..."
BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for variant in Regular Bold Italic BoldItalic Light Medium; do
  try_dl "${BASE}/NotoSans-${variant}.ttf" "$FONTS_DIR/NotoSans-${variant}.ttf" \
    && ui_print "  + NotoSans-${variant}" \
    || ui_print "  ! NotoSans-${variant} skipped (no network)"
done

# ── Plasma wallpapers ─────────────────────────────────────────────────────────
ui_print "- Downloading Plasma Mobile wallpapers..."
WALL_BASE="https://cdn.kde.org/wallpapers"

try_dl "${WALL_BASE}/MilkyWay/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-milkyway.jpg" && ui_print "  + MilkyWay" || ui_print "  ! MilkyWay skipped"
try_dl "${WALL_BASE}/Volna/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-volna.jpg"   && ui_print "  + Volna"    || ui_print "  ! Volna skipped"
try_dl "${WALL_BASE}/Next/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-next.jpg"    && ui_print "  + Next"     || ui_print "  ! Next skipped"

for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] || continue
  cp "$f" "$MODPATH/system/media/default_wallpaper.jpg"
  ui_print "- Default wallpaper: $(basename "$f")"
  break
done

ui_print "- Done. Reboot to apply."
