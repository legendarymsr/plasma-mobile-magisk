#!/sbin/sh
# Sourced by update-binary during flash. Best-effort font/wallpaper download.
# KDE apps install on first boot via service.sh (requires network post-boot).

FONTS_DIR="$MODPATH/system/fonts"
WALLS_DIR="$MODPATH/system/media/wallpapers"
APP_DIR="$MODPATH/system/app"

mkdir -p "$FONTS_DIR" "$WALLS_DIR" "$APP_DIR"

try_dl() {
  local url="$1" dest="$2"
  command -v curl >/dev/null 2>&1 && { curl -fsSL --connect-timeout 10 -o "$dest" "$url" && return 0; }
  command -v wget >/dev/null 2>&1 && { wget -qO "$dest" --timeout=10 "$url" && return 0; }
  return 1
}

ui_print ""
ui_print "=============================="
ui_print "  Plasma Mobile Theme v1.1.0"
ui_print "  KDE Breeze Dark for Android"
ui_print "=============================="
ui_print ""
ui_print "Installing PlasmaLauncher as system priv-app..."
ui_print "  Package : msr.plasma"
ui_print "  APK     : system/priv-app/PlasmaLauncher/"
ui_print "  Target  : Android 8+ (API 26+), Samsung One UI 7 optimised"
ui_print ""

# ── Noto Sans fonts ─────────────────────────────────────────────
ui_print "Downloading Noto Sans fonts (7 weights)..."
BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for v in Regular Bold Italic BoldItalic Light Medium SemiBold; do
  try_dl "${BASE}/NotoSans-${v}.ttf" "$FONTS_DIR/NotoSans-${v}.ttf" \
    && ui_print "  [OK] NotoSans-${v}" \
    || ui_print "  [--] NotoSans-${v} (will retry on first boot)"
done
ui_print ""

# ── Plasma wallpapers ─────────────────────────────────────────────
ui_print "Downloading KDE Plasma wallpapers..."
W="https://cdn.kde.org/wallpapers"
try_dl "$W/MilkyWay/contents/images/3840x2160.jpg"    "$WALLS_DIR/plasma-milkyway.jpg"    \
  && ui_print "  [OK] MilkyWay"    || ui_print "  [--] MilkyWay (will retry on first boot)"
try_dl "$W/Volna/contents/images/3840x2160.jpg"       "$WALLS_DIR/plasma-volna.jpg"       \
  && ui_print "  [OK] Volna"       || ui_print "  [--] Volna (will retry on first boot)"
try_dl "$W/Next/contents/images/3840x2160.jpg"        "$WALLS_DIR/plasma-next.jpg"        \
  && ui_print "  [OK] Next"        || ui_print "  [--] Next (will retry on first boot)"
try_dl "$W/EveningGlow/contents/images/3840x2160.jpg" "$WALLS_DIR/plasma-eveningglow.jpg" \
  && ui_print "  [OK] EveningGlow" || ui_print "  [--] EveningGlow (will retry on first boot)"

for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] && [ -s "$f" ] || continue
  cp "$f" "$MODPATH/system/media/default_wallpaper.jpg"
  ui_print "  Default wallpaper set: $(basename "$f")"
  break
done
ui_print ""

ui_print "What happens on first boot:"
ui_print "  1. PlasmaLauncher APK installed via PackageManager"
ui_print "  2. Plasma Mobile set as default HOME activity"
ui_print "  3. Samsung One UI launcher suppressed (re-enable in Settings)"
ui_print "  4. Breeze Dark applied: dark mode, accent #3DAEE9, font scale 1.0"
ui_print "  5. Gesture navigation enabled (nav_mode=2 / nav_type=0 Samsung)"
ui_print "  6. Battery percentage shown in status bar"
ui_print "  7. Window animations reduced to 0.8x"
ui_print "  8. KDE Connect, Kasts, Markor downloaded from F-Droid (~1 min)"
ui_print ""
ui_print "On first Plasma Mobile launch (Magisk root only):"
ui_print "  - Runs once: gesture overlay + navigation_mode 2 + policy_control"
ui_print "  - Restarts SystemUI to eliminate nav bar at system level"
ui_print "  - Log: /data/local/tmp/plasma-nav.log"
ui_print ""
ui_print "Boot log: /data/local/tmp/plasma-theme.log"
ui_print "Also copied to: /sdcard/Download/plasma-theme.log"
ui_print ""
ui_print "If launcher does not become default automatically:"
ui_print "  Settings > Apps > Default apps > Home app > Plasma Mobile"
ui_print ""
ui_print "To restore stock navigation bar from within the launcher:"
ui_print "  Call Android.restoreNavBar() via the JS bridge"
ui_print "  (sets navigation_mode=0 and restarts SystemUI)"
ui_print ""
ui_print "Reboot to apply."
ui_print ""
