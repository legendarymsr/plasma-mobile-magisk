#!/sbin/sh
# Magisk Module Action — tap the action button in Magisk Manager to run this.
# Re-runs the Plasma Mobile setup without a reboot.

MODDIR=/data/adb/modules/plasma-mobile-theme
LOG=/data/local/tmp/plasma-theme.log

ui_print "--- Plasma Mobile Setup ---"

if pm list packages 2>/dev/null | grep -q "^package:msr.plasma$"; then
  ui_print "+ Plasma launcher: found"
else
  ui_print "! Plasma launcher not in package list — installing..."
  for apk in \
    /system/priv-app/PlasmaLauncher/PlasmaLauncher.apk \
    "$MODDIR/system/priv-app/PlasmaLauncher/PlasmaLauncher.apk"; do
    [ -f "$apk" ] || continue
    pm install -r --user 0 "$apk" 2>/dev/null \
      && ui_print "+ Installed from $apk" \
      || ui_print "! Install FAILED from $apk"
    break
  done
fi

pm set-home-activity msr.plasma/.LauncherActivity 2>/dev/null \
  && ui_print "+ Launcher set as default (pm)" || true
pm set-home-activity --user 0 msr.plasma/.LauncherActivity 2>/dev/null && true || true
cmd role add-role-holder android.app.role.HOME msr.plasma 0 2>/dev/null \
  && ui_print "+ Launcher set as default (role)" || true
settings put secure default_home_package_name msr.plasma 2>/dev/null || true

cmd uimode night yes 2>/dev/null && ui_print "+ Dark mode: on" || ui_print "! Dark mode FAILED"
settings put --user 0 global dark_theme 1 2>/dev/null || settings put global dark_theme 1 2>/dev/null
settings put --user 0 secure ui_night_mode 2 2>/dev/null || true

[ -f "$LOG" ] && ui_print "" && ui_print "Log tail:" \
  && tail -20 "$LOG" | while IFS= read -r line; do ui_print "  $line"; done

ui_print ""
ui_print "If launcher did not switch automatically:"
ui_print "  Settings -> Apps -> Default apps -> Home app -> Plasma Mobile"
ui_print ""
ui_print "Full log: /sdcard/Download/plasma-theme.log"
