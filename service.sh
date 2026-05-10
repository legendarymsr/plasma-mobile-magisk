#!/sbin/sh
# Plasma Mobile Theme — service.sh
# Logs every step to /data/local/tmp/plasma-theme.log for debugging.

LOG=/data/local/tmp/plasma-theme.log
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "--- plasma-mobile-theme service.sh started ---"

# ── wait for full boot ────────────────────────────────────────────────────────
i=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3
  i=$((i+1))
  [ $i -gt 60 ] && log "timed out waiting for boot" && exit 1
done
log "sys.boot_completed=1, sleeping 8s for Samsung services to settle"
sleep 8

# ── device detection ──────────────────────────────────────────────────────────
ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
IS_SAMSUNG=false
[ -n "$ONEUI_VER" ] && IS_SAMSUNG=true
log "OneUI=$ONEUI_VER IS_SAMSUNG=$IS_SAMSUNG"

# settings put wrapper — tries both argument orderings
sp() {
  NS="$1"; KEY="$2"; VAL="$3"
  settings put --user 0 "$NS" "$KEY" "$VAL" 2>/dev/null \
  || settings put "$NS" "$KEY" "$VAL" 2>/dev/null
}

# ── dark mode ─────────────────────────────────────────────────────────────────
cmd uimode night yes                         && log "uimode night: ok"   || log "uimode night: FAILED"
sp global dark_theme 1                       && log "dark_theme=1: ok"  || log "dark_theme=1: FAILED"
sp system darkness_enabled 1                 && log "darkness_enabled: ok" || log "darkness_enabled: FAILED"

# ── font scale ────────────────────────────────────────────────────────────────
sp system font_scale 1.05                    && log "font_scale: ok"    || log "font_scale: FAILED"

# ── navigation ────────────────────────────────────────────────────────────────
if $IS_SAMSUNG; then
  sp global nav_type 0                       && log "nav_type=0: ok"    || log "nav_type=0: FAILED"
else
  sp secure navigation_mode 2                && log "nav_mode=2: ok"    || log "nav_mode=2: FAILED"
fi

# ── accent color ──────────────────────────────────────────────────────────────
if $IS_SAMSUNG; then
  sp secure color_preference 8               && log "color_pref=8: ok"  || log "color_pref=8: FAILED"
else
  sp system accent_color -12529943           && log "accent: ok"        || log "accent: FAILED"
fi

# ── icon shape ────────────────────────────────────────────────────────────────
if $IS_SAMSUNG; then
  sp system app_icon_corner_radius 1         && log "icon_shape: ok"    || log "icon_shape: FAILED"
else
  sp secure icon_shape_overlay_pkg_path squircle && log "icon_shape: ok" || log "icon_shape: FAILED"
fi

# ── status bar clock ─────────────────────────────────────────────────────────
sp system status_bar_clock 1                 && log "clock: ok"         || log "clock: FAILED"

# ── wallpaper ─────────────────────────────────────────────────────────────────
WALL=/system/media/default_wallpaper.jpg
log "wallpaper source exists: $([ -f "$WALL" ] && echo yes || echo NO)"

if [ -f "$WALL" ]; then
  if $IS_SAMSUNG; then
    # Android 12+ FBE: wallpaper lives in credential-encrypted storage.
    # Wait until CE is mounted (user has unlocked at least once since flash).
    CE=/data/system_ce/0
    j=0
    until [ -d "$CE" ]; do
      sleep 3; j=$((j+1))
      [ $j -gt 40 ] && break
    done
    log "CE storage available: $([ -d "$CE" ] && echo yes || echo no)"

    if [ -d "$CE" ]; then
      cp "$WALL" "$CE/wallpaper"      && log "wallpaper copy (home): ok"  || log "wallpaper copy (home): FAILED"
      cp "$WALL" "$CE/wallpaper_lock" && log "wallpaper copy (lock): ok"  || log "wallpaper copy (lock): FAILED"
      chown system:system "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      chmod 600           "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      restorecon          "$CE/wallpaper" "$CE/wallpaper_lock" 2>/dev/null
      am broadcast -a android.intent.action.WALLPAPER_CHANGED 2>/dev/null \
        && log "WALLPAPER_CHANGED broadcast: ok" \
        || log "WALLPAPER_CHANGED broadcast: FAILED"
    else
      log "CE not available — wallpaper skipped (unlock phone and reboot once)"
    fi
  else
    cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null \
      && log "cmd wallpaper: ok" || log "cmd wallpaper: FAILED"
  fi
fi

# ── set Plasma Mobile as default home ────────────────────────────────────────
pm set-home-activity msr.plasma/.LauncherActivity 2>/dev/null \
  && log "home activity: ok" || log "home activity: FAILED (user may need to pick manually)"

log "--- done ---"
