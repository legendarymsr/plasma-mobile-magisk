# plasma-mobile-theme

A Magisk module that skins Android to match [KDE Plasma Mobile](https://invent.kde.org/plasma/plasma-mobile).

No containers, no Linux chroot — pure Android theming via system overlays and boot-time settings.

## What it applies

| Layer | Detail |
|---|---|
| **Accent color** | Breeze Blue `#3DAEE9` |
| **Dark mode** | Forced system-wide |
| **Font** | Noto Sans (KDE's default UI font) replaces Roboto |
| **Wallpapers** | MilkyWay, Volna, Next — pulled from KDE's CDN at flash time |
| **Icon shape** | Squircle (closest to Plasma's app icon style) |
| **Navigation** | Gesture mode (Plasma Mobile has no hardware keys) |
| **Status bar clock** | Centred |
| **Font scale** | 1.05× (Plasma's slightly larger body text) |

Settings are applied via `service.sh` on every boot so they survive app resets.  
Fonts and wallpapers land on `/system` via Magisk's overlay — no system partition write.

## Requirements

- Magisk v20.4+ (or KernelSU with OverlayFS support)
- AOSP-based ROM (Pixel, LineageOS, crDroid, EvolutionX, etc.)
- Internet access during flash (for font + wallpaper download)

## Installation

Flash in Magisk Manager or via recovery:

```
adb sideload plasma-mobile-theme-v1.0.0.zip
```

Reboot. Done.

## Building the ZIP

```sh
cd plasma-mobile-magisk
zip -r9 ../plasma-mobile-theme-v1.0.0.zip . -x '*.git*'
```

## Palette reference

| Token | Hex | Usage |
|---|---|---|
| Breeze Blue | `#3DAEE9` | Accent, links, active elements |
| Midnight | `#1B2430` | Dark background |
| Paper | `#EFF0F1` | Light background |
| Foreground | `#FCFCFC` | Primary text (dark theme) |
| Subtle | `#7F8C8D` | Secondary text |
