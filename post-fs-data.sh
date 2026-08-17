#!/sbin/sh
# post-fs-data.sh — runs after /data mounts, before system_server starts.
# Fixes APK ownership/permissions so PackageManager accepts the priv-app.

APK="/system/priv-app/PrivacySettings/PrivacySettings.apk"
LOG="/data/local/tmp/plasma-pfd.log"

plog() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG" 2>/dev/null; }
plog "=== post-fs-data.sh ==="

if [ -f "$APK" ]; then
  chown 0:0    "$APK" 2>/dev/null && plog "chown ok"      || plog "chown FAILED"
  chmod 644    "$APK" 2>/dev/null && plog "chmod ok"      || plog "chmod FAILED"
  restorecon   "$APK" 2>/dev/null && plog "restorecon ok" \
    || { chcon u:object_r:system_file:s0 "$APK" 2>/dev/null && plog "chcon fallback ok" || plog "chcon FAILED"; }
  restorecon "$(dirname "$APK")" 2>/dev/null || true
  plog "APK: $(wc -c < "$APK" 2>/dev/null) bytes"
else
  plog "APK NOT FOUND at $APK"
fi

plog "=== done ==="
