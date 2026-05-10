#!/sbin/sh
# post-fs-data.sh — runs before system_server, after /data is mounted.
# Patches /data/system/roles.xml so Android 10+ treats Plasma Mobile as the
# default HOME role holder. PackageManager will have already scanned the
# priv-app overlay by the time RoleManagerService reads this file.

PKG="msr.plasma"
ROLES="/data/system/roles.xml"

# roles.xml only exists on Android 10+ after at least one complete boot.
[ -f "$ROLES" ] || exit 0

# Patch the HOME role: replace every <holder> inside the HOME role with ours.
# If the HOME role doesn't exist at all, insert it before </roles>.
awk -v pkg="$PKG" '
BEGIN { in_home=0; needs_role=1 }
/<role name="android.app.role.HOME">/ {
    in_home=1; needs_role=0; print; next
}
in_home && /<holder / { next }
in_home && /<\/role>/ {
    print "        <holder name=\"" pkg "\" />"
    in_home=0
}
/<\/roles>/ {
    if (needs_role) {
        print "    <role name=\"android.app.role.HOME\">"
        print "        <holder name=\"" pkg "\" />"
        print "    </role>"
    }
}
{ print }
' "$ROLES" > "${ROLES}.tmp" 2>/dev/null \
    && mv "${ROLES}.tmp" "$ROLES" 2>/dev/null \
    || true
