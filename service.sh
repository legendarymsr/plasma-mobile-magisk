#!/sbin/sh
# Runs every boot (late_start service stage — system is up, settings DB writable).
# Applies Plasma Mobile / Breeze theme settings that need a live system.

# ── dark mode ─────────────────────────────────────────────────────────────────
settings put global ui_night_mode 2           # force dark
settings put secure ui_night_mode 2

# ── Breeze Blue accent (#3DAEE9 = 0xFF3DAEE9) ─────────────────────────────────
# Works on AOSP-derived ROMs (Pixel, LineageOS, crDroid, EvolutionX, etc.)
settings put system accent_color -12529943   # 0xFF3DAEE9 as signed int32

# ── icon shape: squircle (closest to Plasma's default) ───────────────────────
settings put secure icon_shape_overlay_pkg_path squircle

# ── font scale — Plasma defaults to slightly larger body text ─────────────────
settings put system font_scale 1.05

# ── status bar — hide the clock on the left, keep it centre (Plasma style) ───
settings put secure status_bar_clock 1        # 0=left 1=centre 2=right

# ── edge-to-edge gestures (Plasma Mobile has no HW keys) ─────────────────────
settings put secure navigation_mode 2         # gesture navigation

# ── wallpaper: set the staged system wallpaper if present ────────────────────
WALL=/system/media/default_wallpaper.jpg
if [ -f "$WALL" ]; then
  cmd wallpaper set-wallpaper --file "$WALL" --which both 2>/dev/null
fi
