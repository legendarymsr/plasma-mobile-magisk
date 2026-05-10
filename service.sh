#!/sbin/sh
# Plasma Mobile Theme — service.sh
# Runs post-boot. Applies Breeze Dark theming system-wide.

LOG=/data/local/tmp/plasma-theme.log
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "--- plasma-mobile-theme service.sh started ---"

i=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3; i=$((i+1))
  [ $i -gt 60 ] && log "timed out" && exit 1
done
log "boot completed — sleeping 10s"
sleep 10

ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
IS_SAMSUNG=false; [ -n "$ONEUI_VER" ] && IS_SAMSUNG=true
ANDROID_VER=$(getprop ro.build.version.sdk 2>/dev/null)
log "OneUI=$ONEUI_VER IS_SAMSUNG=$IS_SAMSUNG SDK=$ANDROID_VER"

sp() { settings put --user 0 "$1" "$2" "$3" 2>/dev/null || settings put "$1" "$2" "$3" 2>/dev/null; }

cmd uimode night yes                       && log "uimode night: ok"       || log "uimode night: FAILED"
sp global dark_theme 1                     && log "dark_theme: ok"         || log "dark_theme: FAILED"
sp system darkness_enabled 1               && log "darkness: ok"           || log "darkness: FAILED"
sp secure ui_night_mode 2                  && log "ui_night_mode: ok"      || log "ui_night_mode: FAILED"

if $IS_SAMSUNG; then
  sp secure color_preference 8             && log "samsung accent: ok"     || log "samsung accent: FAILED"
  sp system theme_background_color 0       && log "bg color: ok"           || log "bg color: FAILED"
else
  sp system accent_color -12529943         && log "accent Breeze Blue: ok" || log "accent: FAILED"
fi

sp system font_scale 1.0                   && log "font_scale: ok"         || log "font_scale: FAILED"

if $IS_SAMSUNG; then
  sp global nav_type 0                     && log "nav gestures: ok"       || log "nav_type: FAILED"
else
  sp secure navigation_mode 2              && log "gesture nav: ok"        || log "nav_mode: FAILED"
fi

if $IS_SAMSUNG; then
  sp system app_icon_corner_radius 1       && log "icon squircle: ok"      || log "icon shape: FAILED"
else
  sp secure icon_shape_overlay_pkg_path "com.android.theme.icon.squircle" 2>/dev/null \
    || sp secure icon_shape_overlay_pkg_path "squircle" 2>/dev/null
  log "icon shape attempted"
fi

sp system status_bar_clock 1               && log "status clock: ok"       || log "status clock: FAILED"
sp system status_bar_show_battery_percent 1 && log "battery pct: ok"      || log "battery pct: FAILED"
sp global heads_up_notifications_enabled 1  && log "heads-up: ok"         || log "heads-up: FAILED"
sp global window_animation_scale 0.8       && log "anim window: ok"        || log "anim window: FAILED"
sp global transition_animation_scale 0.8   && log "anim trans: ok"         || log "anim trans: FAILED"
sp global animator_duration_scale 0.8      && log "anim dur: ok"           || log "anim dur: FAILED"

WALL=/system/media/default_wallpaper.jpg
if [ -f "$WALL" ]; then
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
fi

sleep 5
pm set-home-activity msr.plasma/.LauncherActivity 2>/dev/null \
  && log "home activity: ok" || log "home activity: FAILED"

if pm list packages 2>/dev/null | grep -q "org.kde.kdeconnect_tp"; then
  am startservice -n org.kde.kdeconnect_tp/.core.NetworkPacketFetcherProvider 2>/dev/null \
    && log "KDE Connect started" || log "KDE Connect: FAILED"
fi

log "--- done ---"
