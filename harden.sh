#!/sbin/sh
# harden.sh — GrapheneOS-inspired hardening for stock ROM + root.
# Real GrapheneOS hardening (hardened malloc, kernel exploit mitigations,
# sandboxed Google Play compat, USB-C-data-disabled-at-lockscreen) requires
# a full ROM replacement and cannot run on a Samsung One UI device via
# Magisk. This applies the subset that IS achievable as plain Android
# settings/appops/svc commands with root, without touching the OS image.
#
# Sourced by service.sh on every boot. Settings here are split:
#   - "every boot": safe, invisible, no UX disruption — always reapplied
#   - "one-time baseline": things a user might reasonably want back on
#     (NFC, Bluetooth, wireless ADB) — applied once, then left alone so a
#     user's own later toggle in Settings is never silently overridden.

MODDIR=${MODDIR:-/data/adb/modules/plasma-mobile-theme}
LOG=${LOG:-/data/local/tmp/plasma-theme.log}
ONESHOT_MARKER="$MODDIR/.hardening_oneshot_applied"

hlog() { echo "[$(date '+%H:%M:%S')] harden: $*" >> "$LOG"; }
sp() { settings put --user 0 "$1" "$2" "$3" 2>/dev/null || settings put "$1" "$2" "$3" 2>/dev/null; }

hlog "=== hardening pass ==="

# ── Every boot: safe, no UX disruption ────────────────────────────────────────
sp global wifi_connected_mac_randomization_enabled 1 \
  && hlog "wifi MAC randomization: on" || true
device_config put permissions auto_revoke_enabled true 2>/dev/null \
  && hlog "permission auto-revoke: on" || true

# Restrict REQUEST_INSTALL_PACKAGES (sideload installs) to known installers.
# Re-run every boot so newly installed third-party apps are covered too —
# this never disrupts an app that's already running, only future install
# attempts it tries to trigger itself.
ALLOW="com.android.vending org.fdroid.fdroid com.android.packageinstaller com.google.android.packageinstaller com.topjohnwu.magisk msr.plasma"
n=0
for pkg in $(pm list packages -3 2>/dev/null | sed 's/^package://'); do
  case " $ALLOW " in *" $pkg "*) continue ;; esac
  appops set "$pkg" REQUEST_INSTALL_PACKAGES ignore 2>/dev/null && n=$((n + 1))
done
hlog "REQUEST_INSTALL_PACKAGES restricted on ${n} third-party app(s)"

# ── One-time only: respects whatever the user changes afterward ──────────────
if [ ! -f "$ONESHOT_MARKER" ]; then
  hlog "applying one-time baseline (first run only)"
  svc nfc disable                     2>/dev/null && hlog "NFC: off"            || true
  svc bluetooth disable                2>/dev/null && hlog "Bluetooth: off"      || true
  sp global ble_scan_always_enabled 0  && hlog "BLE always-scan: off"  || true
  sp global wifi_scan_always_enabled 0 && hlog "wifi always-scan: off" || true
  sp global adb_wifi_enabled 0         && hlog "wireless ADB: off"     || true
  sp secure install_non_market_apps 0  && hlog "legacy unknown-sources key: off (best-effort)" || true
  touch "$ONESHOT_MARKER" 2>/dev/null
  hlog "one-time baseline applied — re-enable any of the above anytime in Settings"
else
  hlog "one-time baseline already applied — skipping (rm $ONESHOT_MARKER to reapply)"
fi

hlog "=== hardening pass done ==="
