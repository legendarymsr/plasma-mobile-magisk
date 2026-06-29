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
ui_print "  Plasma Mobile Theme v1.4.3"
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

ui_print "What happens on every boot:"
ui_print "  1. PlasmaLauncher APK installed, or updated in place if already present"
ui_print "  2. Samsung One UI Home kept/repaired as your default HOME app"
ui_print "     (Plasma Mobile stays fully installed — switch to it manually anytime)"
ui_print "  3. Samsung One UI Home repaired if a prior version hid it; kept installed"
ui_print "  4. Breeze Dark applied: dark mode, accent #3DAEE9, font scale 1.0"
ui_print "  5. Gesture navigation enabled (nav_mode=2 / nav_type=0 Samsung)"
ui_print "  6. Battery percentage shown in status bar"
ui_print "  7. Window animations reduced to 0.8x"
ui_print "  8. KDE Connect, Kasts, Markor downloaded from F-Droid (~1 min)"
ui_print "  9. GrapheneOS-inspired hardening pass applied (see below)"
ui_print ""
ui_print "On first Plasma Mobile launch (Magisk root only):"
ui_print "  - Runs once: gesture overlay + navigation_mode 2 + policy_control"
ui_print "  - Restarts SystemUI to eliminate nav bar at system level"
ui_print "  - Log: /data/local/tmp/plasma-nav.log"
ui_print ""
ui_print "Boot log: /data/local/tmp/plasma-theme.log"
ui_print "Also copied to: /sdcard/Download/plasma-theme.log"
ui_print ""
ui_print "To make Plasma Mobile your default Home app:"
ui_print "  Settings > Apps > Default apps > Home app > Plasma Mobile"
ui_print "  (the module no longer forces this for you — your choice always sticks)"
ui_print ""
ui_print "To restore stock navigation bar from within the launcher:"
ui_print "  Call Android.restoreNavBar() via the JS bridge"
ui_print "  (sets navigation_mode=0 and restarts SystemUI)"
ui_print ""
ui_print "To switch back to Samsung One UI Home at any time:"
ui_print "  Settings > Apps > Default apps > Home app > One UI Home"
ui_print "  (it is never disabled or hidden — both launchers stay installed)"
ui_print "  Or call Android.restoreOneUIHome() via the JS bridge from Plasma"
ui_print "  Or tap the module's Action button in Magisk Manager (repairs it"
ui_print "  immediately if a prior version left it hidden)"
ui_print ""
ui_print "Hardening applied (GrapheneOS-inspired, root-only — not a full ROM swap):"
ui_print "  Every boot:"
ui_print "    - WiFi MAC randomization forced on"
ui_print "    - Permission auto-revoke (unused apps) forced on"
ui_print "    - Sideload installs (REQUEST_INSTALL_PACKAGES) restricted to"
ui_print "      Play Store / F-Droid / PackageInstaller / Magisk / Plasma"
ui_print "  One-time only (won't fight your own later toggle in Settings):"
ui_print "    - NFC, Bluetooth, BLE/WiFi always-scan, wireless ADB: off"
ui_print "    - Legacy 'install unknown apps' key: off (best-effort)"
ui_print "  Auto-reboot watchdog (forces Before-First-Unlock encryption state):"
ui_print "    - Reboots automatically every 24h of uptime, self-renewing"
ui_print "    - Change interval: echo <hours> > /data/local/tmp/plasma-reboot-hours"
ui_print "  NOT possible without a real GrapheneOS install (Pixel-only ROM):"
ui_print "    hardened malloc, kernel exploit mitigations, sandboxed Google"
ui_print "    Play compatibility layer, USB-C data block at lockscreen"
ui_print "  Log: /data/local/tmp/plasma-theme.log (harden: / watchdog-reboot: lines)"
ui_print "  Re-run hardening any time: tap the module's Action button"
ui_print "  Or open the in-app Privacy & Hardening panel — tap the gear icon"
ui_print "  on the Plasma home screen to toggle each item individually, set"
ui_print "  the reboot interval, or run the full pass on demand"
ui_print ""
ui_print "Reboot to apply."
ui_print ""
