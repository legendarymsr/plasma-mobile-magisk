#!/sbin/sh
# Magisk Module Action — runs when user taps the action button in Magisk Manager.

MODDIR=/data/adb/modules/privacy-hardening
ALOG=/data/local/tmp/plasma-theme-action.log

log() {
  local ts; ts=$(date '+%H:%M:%S' 2>/dev/null)
  echo "[$ts] $*" | tee -a "$ALOG"
}

log "--- Privacy & Hardening Action ---"

# ── Re-run hardening ──────────────────────────────────────────────────────────
if [ -f "$MODDIR/harden.sh" ]; then
  sh "$MODDIR/harden.sh" && log "+ hardening pass: ok" || log "! hardening pass FAILED"
else
  log "! harden.sh not found at $MODDIR/harden.sh"
fi

# ── Show last boot log ────────────────────────────────────────────────────────
BLOG=/data/local/tmp/plasma-theme.log
log ""
if [ -f "$BLOG" ]; then
  log "--- last boot log (plasma-theme.log) ---"
  tail -30 "$BLOG" | while IFS= read -r line; do log "  $line"; done
  log "--- end boot log ---"
else
  log "No boot log found at $BLOG"
fi

mkdir -p /sdcard/Download 2>/dev/null
cp "$ALOG" /sdcard/Download/plasma-theme-action.log 2>/dev/null || true
