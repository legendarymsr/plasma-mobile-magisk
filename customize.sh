#!/sbin/sh
# Runs inside Magisk's installer during flash.
# Downloads Noto Sans fonts and Plasma Mobile wallpapers into the module's
# system/ overlay so they land on /system after reboot.

MODPATH="${MODPATH}"
FONTS_DIR="$MODPATH/system/fonts"
WALLS_DIR="$MODPATH/system/media/wallpapers"

# ── helpers ───────────────────────────────────────────────────────────────────
ui_print() { echo "$1"; }
try_dl() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url" && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url" && return 0
  fi
  return 1
}

ui_print "- Plasma Mobile Theme installer"

# ── Noto Sans (KDE's default UI font) ────────────────────────────────────────
ui_print "- Downloading Noto Sans fonts..."
BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for variant in Regular Bold Italic BoldItalic Light Medium SemiCondensed; do
  try_dl "${BASE}/NotoSans-${variant}.ttf" "$FONTS_DIR/NotoSans-${variant}.ttf" \
    && ui_print "  + NotoSans-${variant}" \
    || ui_print "  ! NotoSans-${variant} skipped (no network)"
done

# ── Plasma Mobile wallpapers ──────────────────────────────────────────────────
ui_print "- Downloading Plasma Mobile wallpapers..."

# Breeze default from KDE's CDN
WALL_BASE="https://cdn.kde.org/wallpapers"
try_dl "${WALL_BASE}/MilkyWay/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-milkyway.jpg" \
  && ui_print "  + MilkyWay" \
  || ui_print "  ! MilkyWay skipped"

try_dl "${WALL_BASE}/Volna/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-volna.jpg" \
  && ui_print "  + Volna" \
  || ui_print "  ! Volna skipped"

try_dl "${WALL_BASE}/Next/contents/images/3840x2160.jpg" \
  "$WALLS_DIR/plasma-next.jpg" \
  && ui_print "  + Next" \
  || ui_print "  ! Next skipped"

# Set first available wallpaper as the system default
for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] || continue
  cp "$f" "$MODPATH/system/media/default_wallpaper.jpg"
  ui_print "- Default wallpaper: $(basename "$f")"
  break
done

ui_print "- Theme files staged. Reboot to apply."
