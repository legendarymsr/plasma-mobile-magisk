#!/sbin/sh
# Runs inside Magisk's installer during flash.
# Downloads Noto Sans fonts and Plasma Mobile wallpapers.
# Handles Samsung-specific font path differences.

FONTS_DIR="$MODPATH/system/fonts"
WALLS_DIR="$MODPATH/system/media/wallpapers"

# ── helpers ───────────────────────────────────────────────────────────────────
ui_print() { echo "$1"; }

try_dl() {
  local url="$1" dest="$2"
  command -v curl >/dev/null 2>&1 && { curl -fsSL -o "$dest" "$url" && return 0; }
  command -v wget >/dev/null 2>&1 && { wget -qO  "$dest" "$url" && return 0; }
  return 1
}

# ── Samsung / OneUI detection ─────────────────────────────────────────────────
ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
IS_SAMSUNG=false
[ -n "$ONEUI_VER" ] && IS_SAMSUNG=true

if $IS_SAMSUNG; then
  ui_print "- Detected OneUI $ONEUI_VER"
  # Samsung ships a separate fonts_base.xml that needs overriding too
  mkdir -p "$MODPATH/system/etc/fonts"
  cp "$MODPATH/system/etc/fonts/fonts.xml" \
     "$MODPATH/system/etc/fonts_base.xml" 2>/dev/null
  # Samsung also reads from /system/etc/SamsungFonts — keep it clean
  mkdir -p "$MODPATH/system/etc/SamsungFonts"
  # Write a minimal SamsungFonts descriptor pointing to Noto Sans
  cat > "$MODPATH/system/etc/SamsungFonts/fonts_config.xml" <<'SFXML'
<?xml version="1.0" encoding="utf-8"?>
<fonts>
  <font name="Noto Sans" family="NotoSans" default="true">
    <file weight="400" style="normal">NotoSans-Regular.ttf</file>
    <file weight="700" style="normal">NotoSans-Bold.ttf</file>
    <file weight="300" style="normal">NotoSans-Light.ttf</file>
  </font>
</fonts>
SFXML
  ui_print "  + Samsung font config written"
else
  ui_print "- Detected AOSP-based ROM"
fi

# ── Noto Sans (KDE default UI font) ──────────────────────────────────────────
ui_print "- Downloading Noto Sans fonts..."
BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for variant in Regular Bold Italic BoldItalic Light Medium; do
  try_dl "${BASE}/NotoSans-${variant}.ttf" "$FONTS_DIR/NotoSans-${variant}.ttf" \
    && ui_print "  + NotoSans-${variant}" \
    || ui_print "  ! NotoSans-${variant} skipped (no network)"
done

# ── Plasma Mobile wallpapers (from KDE CDN) ───────────────────────────────────
ui_print "- Downloading Plasma Mobile wallpapers..."
WALL_BASE="https://cdn.kde.org/wallpapers"

try_dl "${WALL_BASE}/MilkyWay/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-milkyway.jpg"   && ui_print "  + MilkyWay" \
                                     || ui_print "  ! MilkyWay skipped"

try_dl "${WALL_BASE}/Volna/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-volna.jpg"      && ui_print "  + Volna"    \
                                     || ui_print "  ! Volna skipped"

try_dl "${WALL_BASE}/Next/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-next.jpg"       && ui_print "  + Next"     \
                                     || ui_print "  ! Next skipped"

# Stage the first available wallpaper as system default
for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] || continue
  cp "$f" "$MODPATH/system/media/default_wallpaper.jpg"
  ui_print "- Default wallpaper: $(basename "$f")"
  break
done

ui_print "- Theme staged. Reboot to apply."
