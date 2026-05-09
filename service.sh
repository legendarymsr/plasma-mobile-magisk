#!/sbin/sh
# Runs at every boot (late_start service).
# Mounts a tmpfs over /data/plasma-mobile/tmp and ensures
# proot's fake /proc is writable — nothing heavy runs here.

PLASMA_DIR=/data/plasma-mobile

mkdir -p "$PLASMA_DIR/tmp"
mount -t tmpfs tmpfs "$PLASMA_DIR/tmp" -o size=256m,mode=1777 2>/dev/null

# Ensure the rootfs bind-mounts survive across boots
if [ -d "$PLASMA_DIR/rootfs/etc" ]; then
  # keep /dev/shm available inside the container
  mkdir -p "$PLASMA_DIR/rootfs/dev/shm"
  mount --bind /dev/shm "$PLASMA_DIR/rootfs/dev/shm" 2>/dev/null
fi
