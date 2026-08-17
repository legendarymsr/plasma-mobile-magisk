#!/sbin/sh
# service.sh — runs post-boot as root.
# Installs/updates the Privacy Settings app, applies hardening.

LOG=/data/local/tmp/plasma-theme.log
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "=== privacy-hardening service.sh started ==="

i=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3; i=$((i+1))
  [ $i -gt 60 ] && log "timed out waiting for boot" && exit 1
done
log "boot completed — settling 10s for PackageManager"
sleep 10

MODDIR=${MODDIR:-/data/adb/modules/privacy-hardening}
APP_APK="/system/priv-app/PrivacySettings/PrivacySettings.apk"
APP_PKG="msr.plasma"

log "SDK=$(getprop ro.build.version.sdk) OneUI=$(getprop ro.build.version.oneui) MODDIR=$MODDIR"

# ── Install / update the Privacy Settings app ────────────────────────────────
PM_TIMEOUT=""
command -v timeout >/dev/null 2>&1 && PM_TIMEOUT="timeout 30"

if [ -f "$APP_APK" ]; then
  log "BEFORE — versionCode: $(dumpsys package ${APP_PKG} 2>/dev/null | grep -m1 versionCode)"
  log "BEFORE — codePath:    $(dumpsys package ${APP_PKG} 2>/dev/null | grep -m1 codePath)"

  settings put global verifier_verify_adb_installs 0 2>/dev/null
  settings put global package_verifier_enable       0 2>/dev/null

  err=$($PM_TIMEOUT pm install -r -g --user 0 "$APP_APK" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    log "app install OK"
    am force-stop "$APP_PKG" 2>/dev/null
  elif [ $rc -eq 124 ]; then
    log "app install TIMED OUT (30s)"
  else
    log "app install FAILED (rc=$rc): $err"
  fi

  settings put global verifier_verify_adb_installs 1 2>/dev/null
  settings put global package_verifier_enable       1 2>/dev/null

  log "AFTER  — versionCode: $(dumpsys package ${APP_PKG} 2>/dev/null | grep -m1 versionCode)"
  log "AFTER  — codePath:    $(dumpsys package ${APP_PKG} 2>/dev/null | grep -m1 codePath)"
else
  log "APK not found at $APP_APK — Magisk overlay may not have applied"
fi

# ── Privacy hardening ─────────────────────────────────────────────────────────
if [ -f "$MODDIR/harden.sh" ]; then
  log "running harden.sh..."
  sh "$MODDIR/harden.sh" && log "harden.sh: ok" || log "harden.sh: FAILED"
else
  log "harden.sh not found at $MODDIR/harden.sh"
fi

# ── Auto-reboot watchdog ──────────────────────────────────────────────────────
if [ -f "$MODDIR/watchdog-reboot.sh" ]; then
  sh "$MODDIR/watchdog-reboot.sh" &
fi

log "=== service.sh done ==="
mkdir -p /sdcard/Download 2>/dev/null
cp "$LOG" /sdcard/Download/plasma-theme.log 2>/dev/null || true
