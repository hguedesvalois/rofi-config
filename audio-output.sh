#!/usr/bin/env bash
# ------------------------------------------------------------------
#  rofi audio OUTPUT (sink) menu for KDE Plasma
#
#  Lists every playback device; the default sink is marked with ●.
#  Selecting a device makes it the system default, moves any playing
#  streams to it and closes the menu. The mute / volume rows keep the
#  menu open so you can adjust levels in one go.
# ------------------------------------------------------------------

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME="$SCRIPT_DIR/theme.rasi"
MENU_STYLE='listview { lines: 9; }'

notify() { notify-send -i audio-volume-high "$@" 2>/dev/null; }

sink_volume() {   # -> integer percent
    pactl get-sink-volume "$1" 2>/dev/null | grep -oP '\d+(?=%)' | head -1
}

sink_description() {
    pactl list sinks 2>/dev/null \
        | awk -v n="$1" '
            /Name:/      { name = $2 }
            /Description:/ {
                if (name == n) { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); print; exit }
            }'
}

while true; do
    default="$(pactl get-default-sink)"
    vol="$(sink_volume "$default")"
    vol="${vol:-0}"
    muted="$(pactl get-sink-mute "$default" 2>/dev/null | awk '{print $2}')"

    if [[ "$muted" == "yes" ]]; then
        mute_icon="audio-volume-muted-symbolic"
        prompt="Output · muted"
    else
        mute_icon="audio-volume-high-symbolic"
        prompt="Output · ${vol}%"
    fi

    rlabels=()
    ricons=()
    rlabels+=("Mute / Unmute")
    ricons+=("$mute_icon")
    rlabels+=("Volume +15%")
    ricons+=("audio-volume-high-symbolic")
    rlabels+=("Volume -15%")
    ricons+=("audio-volume-low-symbolic")

    while IFS= read -r sink; do
        [[ -n "$sink" ]] || continue
        desc="$(sink_description "$sink")"
        [[ -n "$desc" ]] || desc="$sink"
        svol="$(sink_volume "$sink")"
        marker=""
        [[ "$sink" == "$default" ]] && marker="  ●"
        rlabels+=("${desc}${marker} — ${svol:-0}%")
        ricons+=("audio-card-symbolic")
    done < <(pactl list short sinks | cut -f2)

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
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            ;;
        "Volume +15%")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%+ -l 1.0
            ;;
        "Volume -15%")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%-
            ;;
        *)
            # strip the "  ● — NN%" decorations to recover the sink name
            target="${choice%  ● — *}"
            target="${target% — *}"
            [[ "$target" == "$choice" ]] && target="$choice"
            for sink in $(pactl list short sinks | cut -f2); do
                desc="$(sink_description "$sink")"
                [[ "$target" == "$desc" || "$target" == "$sink" ]] && { match="$sink"; break; }
            done
            if [[ -n "${match:-}" && "$match" != "$default" ]]; then
                pactl set-default-sink "$match"
                # move anything that is currently playing
                for input in $(pactl list short sink-inputs | cut -f1); do
                    pactl move-sink-input "$input" "$match" 2>/dev/null
                done
                notify "Audio output" "Switched to $target"
            fi
            # an output was picked: switch and close the menu
            exit 0
            ;;
    esac
    unset match
done
