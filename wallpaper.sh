#!/usr/bin/env bash
# ------------------------------------------------------------------
#  rofi wallpaper switcher for KDE Plasma
#
#  Shows thumbnails of every image in the Walls directory and sets
#  the chosen picture as wallpaper on all desktops / screens through
#  plasmashell — and mirrors it to the lock screen (kscreenlockerrc).
#  Thumbnails are generated once with ImageMagick and cached in
#  ~/.cache/rofi-scripts/wallpapers (refreshed automatically when an
#  image changes).
#
#  Selecting "Shuffle" picks a random wallpaper.
# ------------------------------------------------------------------

set -u

WALL_DIR="$HOME/Documents/2025-2026/Pessoais/Walls"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-scripts/wallpapers"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME="$SCRIPT_DIR/theme.rasi"

# bigger icons + grid layout for the thumbnail browser
MENU_STYLE='window { width: 780px; }
            listview { columns: 4; lines: 4; }
            element-icon { size: 150px; }'

if [[ ! -d "$WALL_DIR" ]]; then
    notify-send -u critical -i preferences-desktop-wallpaper \
        "Wallpapers" "Directory not found: $WALL_DIR" 2>/dev/null
    exit 1
fi

mkdir -p "$THUMB_DIR"

# --- thumbnails ----------------------------------------------------

make_thumbnails() {
    shopt -s nullglob
    local img thumb
    for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp,bmp}; do
        thumb="$THUMB_DIR/$(basename "${img%.*}").png"
        if [[ ! -f "$thumb" || "$img" -nt "$thumb" ]]; then
            magick "${img}[0]" -auto-orient -thumbnail '260x160>' "$thumb" \
                2>/dev/null || true
        fi
    done
}

# --- talking to plasmashell ----------------------------------------

# prints one "file:///path/to/img" line per screen
current_wallpapers() {
    qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var ds = desktops();
         for (var i = 0; i < ds.length; i++) {
             var d = ds[i];
             d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
             print(d.readConfig('Image'));
         }" 2>/dev/null
}

set_wallpaper() {
    local img="$1"
    qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var ds = desktops();
         for (var i = 0; i < ds.length; i++) {
             var d = ds[i];
             d.wallpaperPlugin = 'org.kde.image';
             d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
             d.writeConfig('Image', 'file://$img');
         }" >/dev/null 2>&1
    # mirror to the lock screen; edited in place so the file keeps the
# exact literal format kscreenlocker itself writes ([Greeter][Wallpaper]…)
    set_lockscreen_wallpaper "$img"
    notify-send -i preferences-desktop-wallpaper \
        "Wallpaper" "Set to $(basename -- "$img")" 2>/dev/null
}

set_lockscreen_wallpaper() {
    local img="file://$1"
    local conf="$HOME/.config/kscreenlockerrc"
    local group='[Greeter][Wallpaper][org.kde.image][General]'
    touch "$conf"
    if grep -qF "$group" "$conf"; then
        sed -i -e "s|^Image=.*|Image=$img|" \
               -e "s|^PreviewImage=.*|PreviewImage=$img|" "$conf"
    else
        printf '%s\nImage=%s\nPreviewImage=%s\n' "$group" "$img" "$img" \
            >> "$conf"
    fi
}

# --- build the menu ------------------------------------------------

make_thumbnails

current="$(current_wallpapers)"

declare -a files=() labels=() icons=()
files+=("__shuffle__")
labels+=("Shuffle")
icons+=("media-playlist-shuffle-symbolic")

shopt -s nullglob
for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp,bmp}; do
    files+=("$img")
    thumb="$THUMB_DIR/$(basename "${img%.*}").png"
    [[ -f "$thumb" ]] || thumb="$img"      # fall back to full image
    label="$(basename -- "$img")"
    grep -qF "file://$img" <<< "$current" && label="● $label"
    labels+=("$label")
    icons+=("$thumb")
done

# rows are emitted with printf: bash variables cannot hold the NUL
# byte that separates an entry from its icon metadata
emit() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${icons[$i]}"
    done
}

choice="$(emit \
    | rofi -dmenu -i -p "Wallpaper" -theme "$THEME" -theme-str "$MENU_STYLE")"
[[ $? -eq 0 && -n "$choice" ]] || exit 1

if [[ "$choice" == "Shuffle" ]]; then
    img="${files[RANDOM % (${#files[@]} - 1) + 1]}"
else
    # match the chosen label back to its file
    img=""
    for i in "${!files[@]}"; do
        [[ $i -eq 0 ]] && continue
        [[ "$choice" == "${labels[$i]}" ]] && { img="${files[$i]}"; break; }
    done
fi

[[ -n "$img" ]] || exit 1
set_wallpaper "$img"
