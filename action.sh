#!/sbin/sh
# Magisk Module Action — runs when user taps the action button in Magisk Manager.
# stdout is shown in the Magisk dialog; everything is also written to the log file.

MODDIR=/data/adb/modules/plasma-mobile-theme
PLASMA_PKG="msr.plasma"
PLASMA_FULL_ACT="${PLASMA_PKG}/msr.plasma.LauncherActivity"
ALOG=/data/local/tmp/plasma-theme-action.log

log() {
  local ts; ts=$(date '+%H:%M:%S' 2>/dev/null)
  echo "[$ts] $*" | tee -a "$ALOG"
}

log "--- Plasma Mobile Setup ---"

# ── Install if absent ─────────────────────────────────────────────────────────
if pm list packages 2>/dev/null | grep -q "^package:${PLASMA_PKG}$"; then
  log "+ Plasma launcher: already installed"
else
  log "! Plasma launcher absent — installing..."
  for apk in \
    "/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk" \
    "$MODDIR/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"; do
    [ -f "$apk" ] || continue
    settings put global verifier_verify_adb_installs 0 2>/dev/null
    settings put global package_verifier_enable       0 2>/dev/null
    err=$(pm install -r -d -g --user 0 "$apk" 2>&1) \
      && log "+ Installed from $apk" \
      || log "! Install FAILED from $apk — $err"
    settings put global verifier_verify_adb_installs 1 2>/dev/null
    settings put global package_verifier_enable       1 2>/dev/null
    break
  done
fi

# ── Set as default home ───────────────────────────────────────────────────────
err=$(pm set-home-activity "$PLASMA_FULL_ACT" 2>&1) \
  && log "+ pm set-home-activity: ok" \
  || log "  pm set-home-activity: $err"
pm set-home-activity --user 0 "$PLASMA_FULL_ACT" 2>/dev/null || true

err=$(cmd role add-role-holder android.app.role.HOME "$PLASMA_PKG" 0 2>&1) \
  && log "+ cmd role: ok" \
  || log "  cmd role: $err"

settings put secure default_home_package_name "$PLASMA_PKG" 2>/dev/null || true

# ── Dark mode ─────────────────────────────────────────────────────────────────
err=$(cmd uimode night yes 2>&1) \
  && log "+ Dark mode: on" \
  || log "! Dark mode FAILED: $err"
settings put global dark_theme 1 2>/dev/null || true
settings put secure ui_night_mode 2 2>/dev/null || true

log ""
log "Full log: /sdcard/Download/plasma-theme.log"
log "If launcher did not switch automatically:"
log "  Settings -> Apps -> Default apps -> Home app -> Plasma Mobile"

mkdir -p /sdcard/Download 2>/dev/null
cp "$ALOG" /sdcard/Download/plasma-theme-action.log 2>/dev/null || true
