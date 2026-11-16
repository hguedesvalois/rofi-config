#!/usr/bin/env bash
# ------------------------------------------------------------------
#  rofi audio INPUT (source / microphone) menu for KDE Plasma
#
#  Lists every recording device (monitor sources are filtered out);
#  the default source is marked with ●. Selecting a device makes it
#  the system default and closes the menu. The mute / gain rows keep
#  the menu open so you can adjust levels in one go.
# ------------------------------------------------------------------

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME="$SCRIPT_DIR/theme.rasi"
MENU_STYLE='listview { lines: 9; }'

source_volume() {   # -> integer percent
    pactl get-source-volume "$1" 2>/dev/null | grep -oP '\d+(?=%)' | head -1
}

source_description() {
    pactl list sources 2>/dev/null \
        | awk -v n="$1" '
            /Name:/      { name = $2 }
            /Description:/ {
                if (name == n) { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); print; exit }
            }'
}

while true; do
    default="$(pactl get-default-source)"
    vol="$(source_volume "$default")"
    vol="${vol:-0}"
    muted="$(pactl get-source-mute "$default" 2>/dev/null | awk '{print $2}')"

    if [[ "$muted" == "yes" ]]; then
        prompt="Input · muted"
    else
        prompt="Input · ${vol}%"
    fi

    rlabels=()
    ricons=()
    rlabels+=("Mute / Unmute")
    ricons+=("audio-input-microphone-symbolic")
    rlabels+=("Gain +15%")
    ricons+=("audio-volume-high-symbolic")
    rlabels+=("Gain -15%")
    ricons+=("audio-volume-low-symbolic")

    while IFS= read -r source; do
        [[ -n "$source" ]] || continue
        desc="$(source_description "$source")"
        [[ -n "$desc" ]] || desc="$source"
        svol="$(source_volume "$source")"
        marker=""
        [[ "$source" == "$default" ]] && marker="  ●"
        rlabels+=("${desc}${marker} — ${svol:-0}%")
        ricons+=("audio-input-microphone-symbolic")
    done < <(pactl list short sources | cut -f2 | grep -v '\.monitor$')

    # rows are emitted with printf: bash variables cannot hold the NUL
    # byte that separates an entry from its icon metadata
    emit() {
        local i
        for i in "${!rlabels[@]}"; do
            printf '%s\0icon\x1f%s\n' "${rlabels[$i]}" "${ricons[$i]}"
        done
    }

    choice="$(emit \
        | rofi -dmenu -i -p "$prompt" -theme "$THEME" -theme-str "$MENU_STYLE")"
    [[ -n "$choice" ]] || exit 0

    case "$choice" in
        "Mute / Unmute")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            ;;
        "Gain +15%")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
            wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 15%+ -l 1.0
            ;;
        "Gain -15%")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
            wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 15%-
            ;;
        *)
            target="${choice%  ● — *}"
            target="${target% — *}"
            [[ "$target" == "$choice" ]] && target="$choice"
            match=""
            for source in $(pactl list short sources | cut -f2 | grep -v '\.monitor$'); do
                desc="$(source_description "$source")"
                [[ "$target" == "$desc" || "$target" == "$source" ]] && { match="$source"; break; }
            done
            if [[ -n "$match" && "$match" != "$default" ]]; then
                pactl set-default-source "$match"
                # move anything that is currently recording
                for input in $(pactl list short source-inputs | cut -f1); do
                    pactl move-source-input "$input" "$match" 2>/dev/null
                done
            fi
            # a source was picked: switch and close the menu
            exit 0
            ;;
    esac
done
