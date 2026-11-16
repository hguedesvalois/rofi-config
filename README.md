# rofi-config/scripts

Collection of Rofi helper scripts for KDE Plasma (audio, power/session, wallpaper) with a shared BreezeDark-inspired theme.

## Scripts

- `audio-output.sh` — Select the default playback device (sink), move active streams, and adjust mute/volume.
- `audio-input.sh` — Select the default recording device (source, monitors excluded), move active inputs, and adjust mute/gain.
- `power-menu.sh` — Session actions: lock, log out, suspend, hibernate (if available), restart, and shut down.
- `wallpaper.sh` — Grid wallpaper picker for images in `~/Documents/2025-2026/Pessoais/Walls`. Sets desktop wallpaper (all screens) via `plasmashell`, mirrors it to the lock screen, and caches thumbnails in `${XDG_CACHE_HOME:-~/.cache}/rofi-scripts/wallpapers`. Includes a shuffle option.
- `theme.rasi` — Shared Rofi theme used by the scripts (rounded, translucent, accent border).

## Requirements

- `bash`, `rofi`
- Audio: `pactl` (PulseAudio/PipeWire), `wpctl` (WirePlumber); optional `notify-send`
- Power: `systemctl`, `loginctl`; `qdbus6` as logout fallback
- Wallpaper: `qdbus6`, `magick` (ImageMagick), `notify-send`

## Usage

Run scripts directly (or bind them in your WM/desktop shortcuts):

```bash
./audio-output.sh
./audio-input.sh
./power-menu.sh
./wallpaper.sh
```

> **Note:** `wallpaper.sh` uses a hardcoded `WALL_DIR`; edit it if your wallpapers live elsewhere.
