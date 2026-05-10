#!/sbin/sh
# Plasma Mobile Theme — service.sh
# Runs post-boot. Downloads assets, installs KDE apps, applies Breeze Dark.

LOG=/data/local/tmp/plasma-theme.log
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "--- plasma-mobile-theme service.sh started ---"

i=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3; i=$((i+1))
  [ $i -gt 60 ] && log "timed out waiting for boot" && exit 1
done
log "boot completed — sleeping 15s"
sleep 15

MODDIR=${MODDIR:-/data/adb/modules/plasma-mobile-theme}
FONTS_DIR="$MODDIR/system/fonts"
WALLS_DIR="$MODDIR/system/media/wallpapers"

ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
IS_SAMSUNG=false; [ -n "$ONEUI_VER" ] && IS_SAMSUNG=true
ANDROID_VER=$(getprop ro.build.version.sdk 2>/dev/null)
log "OneUI=$ONEUI_VER IS_SAMSUNG=$IS_SAMSUNG SDK=$ANDROID_VER MODDIR=$MODDIR"

# ── Download helpers ──────────────────────────────────────────────────────────
try_dl() {
  local url="$1" dest="$2"
  command -v curl >/dev/null 2>&1 && { curl -fsSL --connect-timeout 20 -o "$dest" "$url" && return 0; }
  command -v wget >/dev/null 2>&1 && { wget -qO "$dest" --timeout=20 "$url" && return 0; }
  return 1
}

dl_first() {
  local dest="$1"; shift
  [ -f "$dest" ] && [ -s "$dest" ] && return 0
  for url in "$@"; do
    try_dl "$url" "$dest" && return 0
    rm -f "$dest"
  done
  return 1
}

fdroid_url() {
  local pkg="$1"
  local json vc
  json=$(curl -fsSL --connect-timeout 20 "https://f-droid.org/api/v1/packages/$pkg" 2>/dev/null) \
    || json=$(wget -qO- --timeout=20 "https://f-droid.org/api/v1/packages/$pkg" 2>/dev/null) \
    || return 1
  vc=$(printf '%s' "$json" | sed 's/.*"suggestedVersionCode"[^0-9]*\([0-9][0-9]*\).*/\1/' 2>/dev/null)
  [ -n "$vc" ] && [ "$vc" != "$json" ] || return 1
  echo "https://f-droid.org/repo/${pkg}_${vc}.apk"
}

sp() { settings put --user 0 "$1" "$2" "$3" 2>/dev/null || settings put "$1" "$2" "$3" 2>/dev/null; }

# ── Download missing fonts ────────────────────────────────────────────────────
mkdir -p "$FONTS_DIR"
FONT_BASE="https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans"
for v in Regular Bold Italic BoldItalic Light Medium SemiBold; do
  f="$FONTS_DIR/NotoSans-${v}.ttf"
  [ -f "$f" ] && [ -s "$f" ] && continue
  try_dl "${FONT_BASE}/NotoSans-${v}.ttf" "$f" \
    && log "font ${v}: ok" || log "font ${v}: FAILED"
done

# ── Download missing wallpapers (multiple source fallback) ──────────────────
mkdir -p "$WALLS_DIR"
KDE_CDN="https://cdn.kde.org/wallpapers"
KDE_GH="https://raw.githubusercontent.com/KDE/plasma-workspace-wallpapers/master"

dl_wall() {
  local name="$1"; shift
  local dest="$WALLS_DIR/plasma-${name}.jpg"
  dl_first "$dest" "$@" \
    && log "wall $name: ok" || log "wall $name: FAILED"
}

dl_wall "next" \
  "$KDE_CDN/Next/contents/images/3840x2160.jpg" \
  "$KDE_GH/Next/contents/images/3840x2160.png" \
  "$KDE_GH/Next/contents/images/3840x2160.jpg"

dl_wall "volna" \
  "$KDE_CDN/Volna/contents/images/3840x2160.jpg" \
  "$KDE_GH/Volna/contents/images/3840x2160.jpg" \
  "$KDE_GH/Volna/contents/images/3840x2160.png"

dl_wall "milkyway" \
  "$KDE_CDN/MilkyWay/contents/images/3840x2160.jpg" \
  "$KDE_GH/MilkyWay/contents/images/3840x2160.jpg" \
  "$KDE_GH/MilkyWay/contents/images/5120x2880.jpg"

dl_wall "eveningglow" \
  "$KDE_CDN/EveningGlow/contents/images/3840x2160.jpg" \
  "$KDE_GH/EveningGlow/contents/images/3840x2160.jpg"

for f in "$WALLS_DIR"/*.jpg; do
  [ -f "$f" ] && [ -s "$f" ] || continue
  cp "$f" "$MODDIR/system/media/default_wallpaper.jpg" 2>/dev/null
  log "default wallpaper: $(basename "$f")"
  break
done

# ── Install KDE apps via F-Droid API ────────────────────────────────────────
install_fdroid_app() {
  local pkg="$1" label="$2"
  if pm list packages 2>/dev/null | grep -q "^package:${pkg}$"; then
    log "$label: already installed"; return 0
  fi
  local url apk_tmp="/data/local/tmp/${pkg}.apk"
  url=$(fdroid_url "$pkg") || { log "$label: F-Droid API failed"; return 1; }
  try_dl "$url" "$apk_tmp" || { log "$label: download failed"; return 1; }
  pm install -r "$apk_tmp" 2>/dev/null \
    && log "$label: installed" || log "$label: install FAILED"
  rm -f "$apk_tmp"
}

install_fdroid_app "org.kde.kdeconnect_tp" "KDE Connect"
install_fdroid_app "org.kde.kasts"          "Kasts"
install_fdroid_app "net.gsantner.markor"    "Markor"

# ── Apply Breeze Dark settings ────────────────────────────────────────────
cmd uimode night yes                        && log "uimode night: ok"       || log "uimode night: FAILED"
sp global dark_theme 1                      && log "dark_theme: ok"         || log "dark_theme: FAILED"
sp system darkness_enabled 1                && log "darkness: ok"           || log "darkness: FAILED"
sp secure ui_night_mode 2                   && log "ui_night_mode: ok"      || log "ui_night_mode: FAILED"

if $IS_SAMSUNG; then
  sp secure color_preference 8              && log "samsung accent: ok"     || log "samsung accent: FAILED"
  sp system theme_background_color 0        && log "bg color: ok"           || log "bg color: FAILED"
else
  sp system accent_color -12529943          && log "accent: ok"             || log "accent: FAILED"
fi

sp system font_scale 1.0                    && log "font_scale: ok"         || log "font_scale: FAILED"

if $IS_SAMSUNG; then
  sp global nav_type 0                      && log "nav gestures: ok"       || log "nav_type: FAILED"
else
  sp secure navigation_mode 2               && log "gesture nav: ok"        || log "nav_mode: FAILED"
fi

if $IS_SAMSUNG; then
  sp system app_icon_corner_radius 1        && log "icon squircle: ok"      || log "icon shape: FAILED"
else
  sp secure icon_shape_overlay_pkg_path "com.android.theme.icon.squircle" 2>/dev/null \
    || sp secure icon_shape_overlay_pkg_path "squircle" 2>/dev/null
  log "icon shape attempted"
fi

sp system status_bar_show_battery_percent 1 && log "battery pct: ok"       || log "battery pct: FAILED"
sp global window_animation_scale 0.8        && log "anim: ok"               || log "anim: FAILED"
sp global transition_animation_scale 0.8
sp global animator_duration_scale 0.8

# ── Apply wallpaper ───────────────────────────────────────────────────────────
WALL="$MODDIR/system/media/default_wallpaper.jpg"
[ -f "$WALL" ] && [ -s "$WALL" ] || WALL=/system/media/default_wallpaper.jpg
if [ -f "$WALL" ] && [ -s "$WALL" ]; then
  if $IS_SAMSUNG; then
    CE=/data/system_ce/0
    j=0; until [ -d "$CE" ]; do sleep 3; j=$((j+1)); [ $j -gt 40 ] && break; done
    if [ -d "$CE" ]; then
      cp "$WALL" "$CE/wallpaper"      && log "wallpaper home: ok"  || log "wallpaper home: FAILED"
      cp "$WALL" "$CE/wallpaper_lock" && log "wallpaper lock: ok"  || log "wallpaper lock: FAILED"
      chown system:system "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      chmod 600 "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      restorecon "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      am broadcast -a android.intent.action.WALLPAPER_CHANGED 2>/dev/null && log "wallpaper broadcast: ok"
    fi
  else
    cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null \
      && log "wallpaper set: ok" || log "wallpaper set: FAILED"
  fi
else
  log "wallpaper: no file found"
fi

# ── Ensure Plasma launcher is installed ────────────────────────────────────
PLASMA_PKG="msr.plasma"
PLASMA_ACT="${PLASMA_PKG}/.LauncherActivity"

if ! pm list packages 2>/dev/null | grep -q "^package:${PLASMA_PKG}$"; then
  log "Plasma not in package list — trying explicit install"
  for apk in \
    /system/priv-app/PlasmaLauncher/PlasmaLauncher.apk \
    "$MODDIR/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"; do
    [ -f "$apk" ] || continue
    pm install -r --user 0 "$apk" 2>/dev/null \
      && log "Plasma APK installed from $apk" \
      || log "Plasma APK install FAILED from $apk"
    break
  done
fi

sleep 5
k=0
while ! pm list packages 2>/dev/null | grep -q "^package:${PLASMA_PKG}$"; do
  sleep 2; k=$((k+1)); [ $k -gt 15 ] && break
done

if pm list packages 2>/dev/null | grep -q "^package:${PLASMA_PKG}$"; then
  log "Plasma launcher found in package list"
  pm set-home-activity "$PLASMA_ACT" 2>/dev/null \
    && log "home: pm ok" || log "home: pm FAILED"
  pm set-home-activity --user 0 "$PLASMA_ACT" 2>/dev/null && log "home: pm-user ok" || true
  cmd role add-role-holder android.app.role.HOME "$PLASMA_PKG" 0 2>/dev/null \
    && log "home: role ok" || log "home: role FAILED"
  settings put secure default_home_package_name "$PLASMA_PKG" 2>/dev/null \
    && log "home: settings ok" || true
  log "Manual: Settings -> Apps -> Default apps -> Home app -> Plasma Mobile"
else
  log "Plasma launcher still NOT found — APK may be rejected (check signing)"
fi

if pm list packages 2>/dev/null | grep -q "org.kde.kdeconnect_tp"; then
  am startservice -n org.kde.kdeconnect_tp/.core.NetworkPacketFetcherProvider 2>/dev/null \
    && log "KDE Connect started" || log "KDE Connect: FAILED"
fi

mkdir -p /sdcard/Download 2>/dev/null
cp "$LOG" /sdcard/Download/plasma-theme.log 2>/dev/null && log "log copied to /sdcard/Download/"

log "--- done ---"
