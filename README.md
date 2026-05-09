# plasma-mobile-magisk

A Magisk module that runs [KDE Plasma Mobile](https://invent.kde.org/plasma/plasma-mobile) on Android using an Alpine Linux proot container rendered through [termux-x11](https://github.com/termux/termux-x11).

## How it works

```
Android (Magisk root)
 └── proot
      └── Alpine Linux (edge)
           └── KWin (Wayland compositor)
                └── plasmashell (Plasma Mobile)
                     └── rendered via termux-x11 Wayland socket
```

The module does not bundle a rootfs — it is downloaded and assembled during first-time setup so the ZIP stays small and the rootfs is always fresh from Alpine's edge repos.

## Requirements

- Android device with Magisk v20.4+
- [termux-x11](https://github.com/termux/termux-x11) installed and running
- [Termux](https://termux.dev) installed (`proot`, `curl`, `tar` packages)
- ~2 GB free space in `/data`
- ARM64, ARM32, or x86_64 device

## Installation

1. Flash `plasma-mobile-v*.zip` in Magisk / KernelSU manager.
2. Reboot.
3. Open Termux and run first-time setup:

```sh
su -c plasma-setup
```

This downloads Alpine Linux edge and installs all KDE packages (~800 MB).

## Usage

Start termux-x11, then in Termux:

```sh
su -c plasma-mobile
```

Plasma Mobile will appear in the termux-x11 window.

## Included KDE packages

| Package | Role |
|---|---|
| `kwin` | Wayland compositor |
| `plasma-mobile` | Mobile shell |
| `plasma-dialer` | Phone / dialer UI |
| `spacebar` | SMS app |
| `tokodon` | Mastodon client |
| `neochat` | Matrix client |
| `kirigami` | QML UI framework |

## Directory layout

```
/data/plasma-mobile/
├── rootfs/     Alpine root filesystem
├── home/       Persistent home for the container user
└── tmp/        tmpfs (re-mounted each boot)
```

## Building the ZIP yourself

```sh
cd plasma-mobile-magisk
zip -r ../plasma-mobile-v1.0.0.zip . -x '*.git*' -x 'README.md'
```
