#!/sbin/sh
# Magisk Module Action — runs when user taps the action button in Magisk Manager.
# stdout is shown in the Magisk dialog; everything is also written to the log file.

MODDIR=/data/adb/modules/plasma-mobile-theme
ALOG=/data/local/tmp/plasma-theme-action.log

log() {
  local ts; ts=$(date '+%H:%M:%S' 2>/dev/null)
  echo "[$ts] $*" | tee -a "$ALOG"
}

log "--- Plasma Mobile Setup ---"

# ── Diagnostics: what's on disk vs what's actually installed ─────────────────
for apk in \
  "/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk" \
  "$MODDIR/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"; do
  [ -f "$apk" ] && log "  on disk: $apk ($(wc -c < "$apk" 2>/dev/null) bytes, $(date -r "$apk" '+%Y-%m-%d %H:%M:%S' 2>/dev/null))"
done
log "  installed versionCode: $(dumpsys package msr.plasma 2>/dev/null | grep -m1 versionCode)"
log "  installed codePath:    $(dumpsys package msr.plasma 2>/dev/null | grep -m1 codePath)"

# `pm install` has been observed to hang indefinitely on this device instead
# of failing outright — wrap it in `timeout` so the script always continues
# and we get an explicit log line either way instead of the script silently
# dying mid-run.
PM_TIMEOUT=""
command -v timeout >/dev/null 2>&1 && PM_TIMEOUT="timeout 30"
log "  pm install timeout guard: ${PM_TIMEOUT:-NONE (timeout binary not found)}"

# ── Install if absent, or update in place to pick up any APK changes ─────────
for apk in \
  "/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk" \
  "$MODDIR/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"; do
  [ -f "$apk" ] || continue
  settings put global verifier_verify_adb_installs 0 2>/dev/null
  settings put global package_verifier_enable       0 2>/dev/null
  log "  starting pm install from $apk ..."
  err=$($PM_TIMEOUT pm install -r -g --user 0 "$apk" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    log "+ Installed/updated from $apk"
  elif [ $rc -eq 124 ]; then
    log "! Install TIMED OUT (30s) from $apk — pm install hung"
  else
    log "! Install FAILED (rc=$rc) from $apk — $err"
  fi
  settings put global verifier_verify_adb_installs 1 2>/dev/null
  settings put global package_verifier_enable       1 2>/dev/null
  break
done

log "  AFTER install — versionCode: $(dumpsys package msr.plasma 2>/dev/null | grep -m1 versionCode)"
log "  AFTER install — codePath:    $(dumpsys package msr.plasma 2>/dev/null | grep -m1 codePath)"

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
log "Note: this button no longer changes your default Home app."
log "Switch to Plasma Mobile anytime:"
log "  Settings -> Apps -> Default apps -> Home app -> Plasma Mobile"

mkdir -p /sdcard/Download 2>/dev/null
cp "$ALOG" /sdcard/Download/plasma-theme-action.log 2>/dev/null || true
