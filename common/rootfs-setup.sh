#!/bin/sh
# Bootstraps an Alpine Linux rootfs with KDE Plasma Mobile.
# Runs once from plasma-setup; needs network access.

set -e

PLASMA_DIR=/data/plasma-mobile
ROOTFS="$PLASMA_DIR/rootfs"
ARCH="$(cat /data/adb/modules/plasma-mobile/common/arch 2>/dev/null || uname -m)"

# Alpine mini-rootfs URLs (edge, for latest plasma-mobile packages)
case "$ARCH" in
  aarch64) ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/edge/releases/aarch64/alpine-minirootfs-edge-aarch64.tar.gz" ;;
  x86_64)  ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/edge/releases/x86_64/alpine-minirootfs-edge-x86_64.tar.gz"  ;;
  armv7*)  ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/edge/releases/armv7/alpine-minirootfs-edge-armv7.tar.gz"    ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

TARBALL="$PLASMA_DIR/alpine-rootfs.tar.gz"

echo "[plasma-setup] Downloading Alpine Linux ($ARCH)..."
curl -L --progress-bar -o "$TARBALL" "$ALPINE_URL"

echo "[plasma-setup] Extracting rootfs..."
mkdir -p "$ROOTFS"
tar -xzf "$TARBALL" -C "$ROOTFS"
rm -f "$TARBALL"

echo "[plasma-setup] Configuring Alpine repos (edge + testing)..."
cat > "$ROOTFS/etc/apk/repositories" <<'REPOS'
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
REPOS

# resolv.conf so the container has DNS
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"

echo "[plasma-setup] Installing Plasma Mobile packages (this takes a few minutes)..."
# proot invocation — no real root needed inside the container
proot \
  --rootfs="$ROOTFS" \
  --bind=/dev \
  --bind=/proc \
  --bind=/sys \
  --bind="$PLASMA_DIR/home:/root" \
  --change-id=0:0 \
  /bin/sh -c '
    set -e
    apk update
    apk upgrade

    # Wayland + XWayland display
    apk add wayland-protocols weston xwayland

    # Qt6 Wayland platform
    apk add qt6-qtbase qt6-qtwayland qt6-qtdeclarative

    # KDE Frameworks (subset required by plasma-mobile)
    apk add \
      kf6-kconfig \
      kf6-kwindowsystem \
      kf6-ki18n \
      kf6-kservice \
      kf6-solid \
      kf6-knotifications \
      kf6-kio \
      kf6-kirigami

    # KWin (Wayland compositor) + Plasma Mobile shell
    apk add kwin plasma-mobile plasma-mobile-sounds

    # Essential mobile apps
    apk add plasma-dialer spacebar tokodon neochat

    # Utilities
    apk add dbus mesa-dri-gallium font-noto font-noto-emoji

    echo "[plasma-setup] Packages installed."
  '

echo "[plasma-setup] Writing container launch helper..."
cat > "$ROOTFS/usr/local/bin/start-plasma" <<'LAUNCH'
#!/bin/sh
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
export XDG_RUNTIME_DIR=/run/user/0
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_SESSION_TYPE=wayland
export KDE_FULL_SESSION=true
export PLASMA_INTEGRATION_NO_KDE_CHECK=true

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --nofork --nopidfile &
sleep 1
exec startplasma-wayland
LAUNCH
chmod +x "$ROOTFS/usr/local/bin/start-plasma"

echo "[plasma-setup] Done. Run 'plasma-mobile' to start."
