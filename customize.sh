#!/sbin/sh
# Sourced by update-binary during flash. Downloads fonts, wallpapers, KDE apps.

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

# ── Noto Sans fonts ─────────────────────────────────────────────────────────────────
ui_print "- Downloading Noto Sans fonts..."
BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for v in Regular Bold Italic BoldItalic Light Medium SemiBold; do
  try_dl "${BASE}/NotoSans-${v}.ttf" "$FONTS_DIR/NotoSans-${v}.ttf" \
    && ui_print "  + NotoSans-${v}" \
    || ui_print "  ! NotoSans-${v} skipped"
done

# ── Plasma wallpapers ───────────────────────────────────────────────────────────────
ui_print "- Downloading Plasma Mobile wallpapers..."
W="https://cdn.kde.org/wallpapers"
try_dl "$W/MilkyWay/contents/images/3840x2160.jpg" "$WALLS_DIR/plasma-milkyway.jpg" \
  && ui_print "  + MilkyWay" || ui_print "  ! MilkyWay skipped"
try_dl "$W/Volna/contents/images/3840x2160.jpg"    "$WALLS_DIR/plasma-volna.jpg"    \
  && ui_print "  + Volna"    || ui_print "  ! Volna skipped"
try_dl "$W/Next/contents/images/3840x2160.jpg"     "$WALLS_DIR/plasma-next.jpg"     \
  && ui_print "  + Next"     || ui_print "  ! Next skipped"
try_dl "$W/EveningGlow/contents/images/3840x2160.jpg" "$WALLS_DIR/plasma-eveningglow.jpg" \
  && ui_print "  + EveningGlow" || ui_print "  ! EveningGlow skipped"

for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] || continue
  cp "$f" "$MODPATH/system/media/default_wallpaper.jpg"
  ui_print "- Default wallpaper: $(basename "$f")"
  break
done

# ── KDE Android apps ──────────────────────────────────────────────────────────────
ui_print "- Downloading KDE Android apps..."

mkdir -p "$APP_DIR/KDEConnect"
try_dl "https://f-droid.org/repo/org.kde.kdeconnect_tp_10403.apk" \
  "$APP_DIR/KDEConnect/KDEConnect.apk" \
  && ui_print "  + KDE Connect" || ui_print "  ! KDE Connect skipped"

mkdir -p "$APP_DIR/Kasts"
try_dl "https://f-droid.org/repo/org.kde.kasts_21.apk" \
  "$APP_DIR/Kasts/Kasts.apk" \
  && ui_print "  + Kasts" || ui_print "  ! Kasts skipped"

mkdir -p "$APP_DIR/Markor"
try_dl "https://f-droid.org/repo/net.gsantner.markor_150.apk" \
  "$APP_DIR/Markor/Markor.apk" \
  && ui_print "  + Markor" || ui_print "  ! Markor skipped"

set_perm_recursive "$APP_DIR" root root 0755 0644

ui_print "- Done. Reboot to apply."
