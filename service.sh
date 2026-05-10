#!/sbin/sh
# Applies Plasma Mobile / Breeze theme settings at boot.
# Must wait for sys.boot_completed — service.sh fires before the settings
# provider is ready, so all settings put calls would silently fail without it.

# ── wait for full boot ────────────────────────────────────────────────────────
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 3   # give Samsung's own boot services time to settle first

# ── device detection ──────────────────────────────────────────────────────────
ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
IS_SAMSUNG=false
[ -n "$ONEUI_VER" ] && IS_SAMSUNG=true

sp() { settings put --user 0 "$@" 2>/dev/null; }

# ── dark mode ─────────────────────────────────────────────────────────────────
cmd uimode night yes                    # works on all ROMs
$IS_SAMSUNG && sp global dark_theme 1   # OneUI-specific reinforcement

# ── font scale ────────────────────────────────────────────────────────────────
sp system font_scale 1.05

# ── navigation — gesture mode ─────────────────────────────────────────────────
if $IS_SAMSUNG; then
  # OneUI: 0 = fullscreen gestures, 1 = 3-button
  sp global nav_type 0
else
  sp secure navigation_mode 2
fi

# ── accent color ──────────────────────────────────────────────────────────────
if $IS_SAMSUNG; then
  # OneUI 7 Color Palette index — 8 = Blue (closest to Breeze Blue #3DAEE9)
  sp secure color_preference 8
else
  sp system accent_color -12529943   # 0xFF3DAEE9 signed int32
fi

# ── icon shape ────────────────────────────────────────────────────────────────
if $IS_SAMSUNG; then
  # OneUI: 0=circle 1=squircle 2=rounded-square 3=square
  sp system app_icon_corner_radius 1
else
  sp secure icon_shape_overlay_pkg_path squircle
fi

# ── status bar clock — centred ────────────────────────────────────────────────
sp system status_bar_clock 1

# ── wallpaper ─────────────────────────────────────────────────────────────────
WALL=/system/media/default_wallpaper.jpg
if [ -f "$WALL" ]; then
  if $IS_SAMSUNG; then
    # Copy directly into Samsung's wallpaper store then send a refresh broadcast
    cp "$WALL" /data/system/users/0/wallpaper
    cp "$WALL" /data/system/users/0/wallpaper_lock
    chmod 600 /data/system/users/0/wallpaper /data/system/users/0/wallpaper_lock
    am broadcast -a android.intent.action.WALLPAPER_CHANGED 2>/dev/null
  else
    cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null
  fi
fi
