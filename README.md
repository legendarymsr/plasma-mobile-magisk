# plasma-mobile-theme

A Magisk module that skins Android to match [KDE Plasma Mobile](https://invent.kde.org/plasma/plasma-mobile).

Supports **Samsung OneUI 7** and AOSP-based ROMs (Pixel, LineageOS, crDroid, EvolutionX, etc.).

## What it applies

| Layer | AOSP | OneUI 7 |
|---|---|---|
| **Dark mode** | `ui_night_mode=2` | `dark_theme=1` + `cmd uimode night yes` |
| **Accent color** | Breeze Blue `#3DAEE9` via `accent_color` | Color Palette index 8 (Blue) |
| **Font** | Noto Sans via `fonts.xml` | Noto Sans via `fonts.xml` + `fonts_base.xml` + `SamsungFonts/fonts_config.xml` |
| **Icon shape** | Squircle via `icon_shape_overlay_pkg_path` | Squircle via `app_icon_style=1` |
| **Navigation** | `navigation_mode=2` (gestures) | `nav_type=0` (fullscreen gestures) |
| **Status bar clock** | Centred | Centred via `status_bar_clock=1` |
| **Wallpaper** | `cmd wallpaper set-wallpaper` | Samsung wallpaper broadcast + fallback |
| **Font scale** | 1.05× | 1.05× |

Wallpapers (MilkyWay, Volna, Next) are pulled from KDE's CDN at flash time.

## Requirements

- Magisk v20.4+ (or KernelSU with OverlayFS)
- Samsung OneUI 7 **or** any AOSP-based ROM
- Unlocked bootloader (Knox flag will already be tripped on Samsung)
- Internet access during flash (font + wallpaper download)

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

## Notes

- On OneUI 7, Samsung's Color Palette re-derives from the wallpaper on boot.  
  The module sets `persist.sys.samsung.color_palette_lock=1` to keep Blue (index 8) stable.
- Knox warranty void status is unaffected — unlocking the bootloader already trips it.
- If Samsung's font picker overrides Noto Sans after a theme reset, reflash the module.
