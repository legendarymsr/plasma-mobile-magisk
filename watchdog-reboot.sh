#!/sbin/sh
# watchdog-reboot.sh — periodic forced reboot (GrapheneOS "Auto Reboot" analog).
#
# Security rationale: a reboot returns the device to Before-First-Unlock (BFU)
# state under file-based encryption — most user data (and Plasma's own
# SharedPreferences/logs) is inaccessible to anyone without the lockscreen
# credential until the device is unlocked once post-boot. GrapheneOS ships a
# dedicated "Auto Reboot" toggle for exactly this; this script gets the same
# property on stock Android via a plain scheduled reboot.
#
# Launched once per boot, detached, by service.sh. The timer always restarts
# from zero at boot, so it self-renews every reboot — no persistent state.
# Change the interval without re-flashing: edit $CONF and it takes effect on
# the next boot (or kill + relaunch this script to apply immediately).

LOG=/data/local/tmp/plasma-theme.log
CONF=/data/local/tmp/plasma-reboot-hours
DEFAULT_HOURS=24

wlog() { echo "[$(date '+%H:%M:%S')] watchdog-reboot: $*" >> "$LOG"; }

HOURS="$DEFAULT_HOURS"
if [ -f "$CONF" ]; then
  v=$(cat "$CONF" 2>/dev/null)
  case "$v" in
    ''|*[!0-9]*) wlog "ignoring invalid $CONF value '$v', using default" ;;
    *) HOURS="$v" ;;
  esac
fi

wlog "scheduled in ${HOURS}h (edit $CONF, in whole hours, to change)"
sleep "$((HOURS * 3600))"
wlog "rebooting now (${HOURS}h elapsed)"
reboot
