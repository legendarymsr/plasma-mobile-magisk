#!/sbin/sh
# Runs inside Magisk's installer environment after update-binary unpacks files.

ui_print "- Checking architecture..."
case "$ARCH" in
  arm64) ARCH_TAG="aarch64" ;;
  arm)   ARCH_TAG="armv7"   ;;
  x86_64)ARCH_TAG="x86_64"  ;;
  x86)   ARCH_TAG="x86"     ;;
  *) abort "Unsupported arch: $ARCH" ;;
esac

ui_print "  arch: $ARCH_TAG"

# Store arch so service.sh and plasma-setup can read it
echo "$ARCH_TAG" > "$MODPATH/common/arch"

# Ensure the rootfs directory exists (rootfs is downloaded at setup time, not bundled)
mkdir -p /data/plasma-mobile/rootfs
mkdir -p /data/plasma-mobile/home

ui_print "- Data directories created at /data/plasma-mobile"
