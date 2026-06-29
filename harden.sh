#!/sbin/sh
# harden.sh — GrapheneOS-inspired hardening for stock ROM + root.
# Real GrapheneOS hardening (hardened malloc, kernel exploit mitigations,
# sandboxed Google Play compat, USB-C-data-disabled-at-lockscreen) requires
# a full ROM replacement and cannot run on a Samsung One UI device via
# Magisk. This applies the subset that IS achievable as plain Android
# settings/appops/svc commands with root, without touching the OS image.
#
# Sourced by service.sh on every boot, and re-runnable on demand from the
# module's Action button or the in-app "Privacy & Hardening" settings panel
# (LauncherActivity's PlasmaJS bridge writes $CONF when a toggle is changed).
#
# Two modes:
#   - No $CONF file (default, nothing touched the settings panel yet):
#     legacy behavior — safe items reapplied every boot, the radio/scan
#     items applied exactly ONCE (one-shot marker) so a user's own later
#     toggle in stock Settings is never silently overridden.
#   - $CONF present (user opened the in-app settings panel at least once):
#     every key in it is treated as the live desired state and enforced
#     every boot, in both directions — this IS the control panel now.

MODDIR=${MODDIR:-/data/adb/modules/plasma-mobile-theme}
LOG=${LOG:-/data/local/tmp/plasma-theme.log}
ONESHOT_MARKER="$MODDIR/.hardening_oneshot_applied"
CONF=/data/local/tmp/plasma-harden.conf

hlog() { echo "[$(date '+%H:%M:%S')] harden: $*" >> "$LOG"; }
sp() { settings put --user 0 "$1" "$2" "$3" 2>/dev/null || settings put "$1" "$2" "$3" 2>/dev/null; }

CONFIG_MODE=0
if [ -f "$CONF" ]; then
  . "$CONF"
  CONFIG_MODE=1
fi

# Defaults match the pre-settings-panel hardcoded behavior exactly.
WIFI_MAC_RANDOM=${WIFI_MAC_RANDOM:-1}
AUTO_REVOKE=${AUTO_REVOKE:-1}
RESTRICT_SIDELOAD=${RESTRICT_SIDELOAD:-1}
NFC_DISABLED=${NFC_DISABLED:-1}
BLUETOOTH_DISABLED=${BLUETOOTH_DISABLED:-1}
BLE_SCAN_DISABLED=${BLE_SCAN_DISABLED:-1}
WIFI_SCAN_DISABLED=${WIFI_SCAN_DISABLED:-1}
WIRELESS_ADB_DISABLED=${WIRELESS_ADB_DISABLED:-1}

hlog "=== hardening pass (config-mode=${CONFIG_MODE}) ==="

# ── Every boot: safe, no UX disruption ────────────────────────────────────────
if [ "$WIFI_MAC_RANDOM" = "1" ]; then
  sp global wifi_connected_mac_randomization_enabled 1 && hlog "wifi MAC randomization: on" || true
else
  sp global wifi_connected_mac_randomization_enabled 0 && hlog "wifi MAC randomization: off (set in app)" || true
fi

if [ "$AUTO_REVOKE" = "1" ]; then
  device_config put permissions auto_revoke_enabled true 2>/dev/null && hlog "permission auto-revoke: on" || true
else
  device_config put permissions auto_revoke_enabled false 2>/dev/null && hlog "permission auto-revoke: off (set in app)" || true
fi

# Restrict REQUEST_INSTALL_PACKAGES (sideload installs) to known installers.
# Re-run every boot so newly installed third-party apps are covered too —
# this never disrupts an app that's already running, only future install
# attempts it tries to trigger itself.
ALLOW="com.android.vending org.fdroid.fdroid com.android.packageinstaller com.google.android.packageinstaller com.topjohnwu.magisk msr.plasma"
if [ "$RESTRICT_SIDELOAD" = "1" ]; then
  n=0
  for pkg in $(pm list packages -3 2>/dev/null | sed 's/^package://'); do
    case " $ALLOW " in *" $pkg "*) continue ;; esac
    appops set "$pkg" REQUEST_INSTALL_PACKAGES ignore 2>/dev/null && n=$((n + 1))
  done
  hlog "REQUEST_INSTALL_PACKAGES restricted on ${n} third-party app(s)"
else
  for pkg in $(pm list packages -3 2>/dev/null | sed 's/^package://'); do
    appops set "$pkg" REQUEST_INSTALL_PACKAGES allow 2>/dev/null
  done
  hlog "REQUEST_INSTALL_PACKAGES restriction lifted (set in app)"
fi

# ── Radio/scan items ───────────────────────────────────────────────────────────
if [ "$CONFIG_MODE" = "1" ]; then
  # User has opened the settings panel — these are now live-enforced every
  # boot just like the items above, not one-shot.
  if [ "$NFC_DISABLED" = "1" ]; then
    svc nfc disable 2>/dev/null && hlog "NFC: off"
  else
    svc nfc enable 2>/dev/null && hlog "NFC: on (set in app)"
  fi
  if [ "$BLUETOOTH_DISABLED" = "1" ]; then
    svc bluetooth disable 2>/dev/null && hlog "Bluetooth: off"
  else
    svc bluetooth enable 2>/dev/null && hlog "Bluetooth: on (set in app)"
  fi
  if [ "$BLE_SCAN_DISABLED" = "1" ]; then
    sp global ble_scan_always_enabled 0 && hlog "BLE always-scan: off"
  else
    sp global ble_scan_always_enabled 1 && hlog "BLE always-scan: on (set in app)"
  fi
  if [ "$WIFI_SCAN_DISABLED" = "1" ]; then
    sp global wifi_scan_always_enabled 0 && hlog "wifi always-scan: off"
  else
    sp global wifi_scan_always_enabled 1 && hlog "wifi always-scan: on (set in app)"
  fi
  if [ "$WIRELESS_ADB_DISABLED" = "1" ]; then
    sp global adb_wifi_enabled 0 && hlog "wireless ADB: off"
  else
    sp global adb_wifi_enabled 1 && hlog "wireless ADB: on (set in app)"
  fi
else
  # Legacy one-shot behavior, unchanged: applied once, then left alone so a
  # user's own later toggle in stock Settings is never silently overridden.
  if [ ! -f "$ONESHOT_MARKER" ]; then
    hlog "applying one-time baseline (first run only)"
    svc nfc disable                     2>/dev/null && hlog "NFC: off"            || true
    svc bluetooth disable                2>/dev/null && hlog "Bluetooth: off"      || true
    sp global ble_scan_always_enabled 0  && hlog "BLE always-scan: off"  || true
    sp global wifi_scan_always_enabled 0 && hlog "wifi always-scan: off" || true
    sp global adb_wifi_enabled 0         && hlog "wireless ADB: off"     || true
    sp secure install_non_market_apps 0  && hlog "legacy unknown-sources key: off (best-effort)" || true
    touch "$ONESHOT_MARKER" 2>/dev/null
    hlog "one-time baseline applied — re-enable any of the above anytime in Settings, or open the in-app Privacy & Hardening panel for a persistent control panel"
  else
    hlog "one-time baseline already applied — skipping (rm $ONESHOT_MARKER to reapply, or use the in-app settings panel)"
  fi
fi

hlog "=== hardening pass done ==="
