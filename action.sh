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

# ── Repair Samsung One UI launcher ────────────────────────────────────────────
# Earlier module versions ran `pm hide` on it, which also clears it from
# Settings > Apps. Undo that here so tapping this action repairs it immediately
# without waiting for a reboot.
err=$(pm unhide --user 0 com.sec.android.app.launcher 2>&1) \
  && log "+ Samsung launcher unhidden" \
  || log "  Samsung launcher unhide: $err"
err=$(pm enable --user 0 com.sec.android.app.launcher 2>&1) \
  && log "+ Samsung launcher enabled" \
  || log "  Samsung launcher enable: $err"

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

# ── Hardening (every-boot subset only — see harden.sh for the full pass) ──────
if [ -f "$MODDIR/harden.sh" ]; then
  LOG="$ALOG" sh "$MODDIR/harden.sh" && log "+ hardening pass: ok" || log "  hardening pass: see $ALOG"
fi

log ""
log "Full log: /sdcard/Download/plasma-theme.log"
log "If launcher did not switch automatically:"
log "  Settings -> Apps -> Default apps -> Home app -> Plasma Mobile"

mkdir -p /sdcard/Download 2>/dev/null
cp "$ALOG" /sdcard/Download/plasma-theme-action.log 2>/dev/null || true
