#!/sbin/sh
# Applies Plasma Mobile / Breeze theme settings at every boot.
# Detects OneUI 7 (Samsung) and uses the correct settings keys.

# ── device detection ──────────────────────────────────────────────────────────
ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null)
MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')

is_samsung() { [ -n "$ONEUI_VER" ] || echo "$MANUFACTURER" | grep -q samsung; }

# ── dark mode ─────────────────────────────────────────────────────────────────
# cmd uimode works on both AOSP and OneUI
cmd uimode night yes

if is_samsung; then
  # OneUI-specific dark mode keys (OneUI 4+)
  settings put global dark_theme 1
  settings put system darkness_enabled 1
else
  settings put global ui_night_mode 2
  settings put secure ui_night_mode 2
fi

# ── accent / color palette ────────────────────────────────────────────────────
if is_samsung; then
  # OneUI 7 Color Palette — index 8 = Blue (closest to Breeze Blue #3DAEE9)
  # Indices: 1=Red 2=Orange 3=Yellow 4=Lime 5=Green 6=Teal 7=Cyan 8=Blue
  #          9=Indigo 10=Violet 11=Pink 12=Magenta
  settings put secure color_preference 8
  # Lock the palette to our chosen color (don't re-derive from wallpaper)
  settings put secure color_paletteStyle 1
else
  # AOSP / LineageOS / crDroid / EvolutionX
  # 0xFF3DAEE9 as signed int32 = -12529943
  settings put system accent_color -12529943
fi

# ── font scale ────────────────────────────────────────────────────────────────
settings put system font_scale 1.05

# ── navigation — gesture mode ─────────────────────────────────────────────────
if is_samsung; then
  # OneUI gesture: 0 = fullscreen swipe gestures, 1 = 3-button bar
  settings put global nav_type 0
  settings put secure navbar_gesture_hint_count 0   # hide gesture hint bar
else
  settings put secure navigation_mode 2
fi

# ── icon shape ────────────────────────────────────────────────────────────────
if is_samsung; then
  # OneUI icon shapes: 0=circle 1=squircle 2=rounded-square 3=square
  settings put system app_icon_style 1   # squircle
else
  settings put secure icon_shape_overlay_pkg_path squircle
fi

# ── status bar clock — centred ────────────────────────────────────────────────
if is_samsung; then
  settings put system status_bar_clock 1   # 0=left 1=center 2=right (OneUI)
else
  settings put secure status_bar_clock 1
fi

# ── wallpaper ─────────────────────────────────────────────────────────────────
WALL=/system/media/default_wallpaper.jpg
if [ -f "$WALL" ]; then
  if is_samsung; then
    # Samsung uses am startservice for wallpaper on OneUI
    am broadcast \
      -a com.samsung.android.app.wallpaper.SET_WALLPAPER \
      --es wallpaper_path "$WALL" 2>/dev/null \
    || cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null
  else
    cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null
  fi
fi
