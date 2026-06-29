#!/sbin/sh
# post-fs-data.sh
# Runs after /data is mounted but BEFORE system_server starts.
# Two jobs:
#   1. Fix APK ownership/permissions/SELinux so PackageManager accepts it.
#   2. Scrub any stale cert record from packages.xml so PM does a fresh install.
# Does NOT touch roles.xml / the HOME role — service.sh owns default-home
# logic (one-time restore of Samsung One UI Home, never re-forced after that),
# and this script used to fight it by re-injecting Plasma as HOME on every
# boot before service.sh ever got a chance to run.

PKG="msr.plasma"
APK="/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"
PKG_XML="/data/system/packages.xml"
LOG="/data/local/tmp/plasma-pfd.log"

plog() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG" 2>/dev/null; }
plog "=== post-fs-data.sh ==="

# ── 1. Fix APK file attributes ─────────────────────────────────────────────────
# Magisk bind-mounts the overlay but does not guarantee the file inherits the
# correct context. PackageManager on Samsung may skip APKs with wrong context
# even in permissive mode (it logs a warning and moves on).
if [ -f "$APK" ]; then
    SZ=$(wc -c < "$APK" 2>/dev/null || echo '?')
    CTX=$(ls -Z "$APK" 2>/dev/null | awk '{print $1}')
    plog "APK found: ${SZ} bytes  context=${CTX}"

    chown 0:0 "$APK"                                  2>/dev/null && plog "chown ok"   || plog "chown FAILED"
    chmod 644 "$APK"                                  2>/dev/null && plog "chmod ok"   || plog "chmod FAILED"
    # restorecon uses the device's own file_contexts — correct for both AOSP and
    # Samsung. Fall back to an explicit label only if restorecon is missing.
    restorecon "$APK"                                 2>/dev/null && plog "restorecon ok" \
        || { chcon u:object_r:system_file:s0 "$APK"  2>/dev/null && plog "chcon fallback ok" || plog "chcon FAILED"; }
    restorecon "$(dirname "$APK")"                    2>/dev/null || true
else
    plog "APK NOT FOUND at $APK — Magisk overlay did not apply, or wrong path"
    plog "Module dir contents:"
    ls /data/adb/modules/plasma-mobile-theme/system/priv-app/ >> "$LOG" 2>/dev/null || true
fi

# ── 2. Scrub stale cert record from packages.xml ───────────────────────────────
# packages.xml persists the signing cert from the last install. If the user
# previously flashed a module built with a different signing key the record
# survives pm uninstall --user 0 and causes INSTALL_FAILED_UPDATE_INCOMPATIBLE
# on every subsequent pm install. Removing the <package> block here, before PM
# reads the file, lets PM treat the next install as a fresh one.
if [ -f "$PKG_XML" ] && grep -qF "\"$PKG\"" "$PKG_XML" 2>/dev/null; then
    plog "stale cert record found in packages.xml — removing"
    cp "$PKG_XML" "${PKG_XML}.plasma.bak" 2>/dev/null
    # Python3 is always present on Android 8+.
    python3 - <<PYEOF 2>/dev/null && plog "packages.xml cleaned" || plog "packages.xml clean FAILED"
import re, os, sys
f = "$PKG_XML"
txt = open(f).read()
cleaned = re.sub(
    r'\n[ \t]*<package [^>]*\bname="$PKG"[^>]*>.*?</package>',
    '', txt, flags=re.DOTALL
)
if cleaned == txt:
    # Single-line self-closing form
    cleaned = re.sub(r'\n[ \t]*<package [^>]*\bname="$PKG"[^>]*/>', '', cleaned)
if cleaned != txt:
    tmp = f + '.plasma.tmp'
    open(tmp, 'w').write(cleaned)
    os.rename(tmp, f)
    sys.exit(0)
sys.exit(1)
PYEOF
else
    plog "no stale cert record in packages.xml"
fi

plog "=== done ==="
