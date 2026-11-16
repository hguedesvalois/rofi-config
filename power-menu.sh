#!/usr/bin/env bash
# ------------------------------------------------------------------
#  rofi power / session menu for KDE Plasma
#
#  Every action runs immediately: logout ends the session and
#  restart / shut down go straight to systemd without any KDE
#  confirmation dialog. (There is no undo — pick carefully.)
# ------------------------------------------------------------------

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME="$SCRIPT_DIR/theme.rasi"
MENU_STYLE='listview { lines: 6; }'

# label, icon  (parallel arrays)
labels=()
icons=()

add() { labels+=("$1"); icons+=("$2"); }

add "Lock Screen" "system-lock-screen-symbolic"
add "Log Out"     "system-log-out-symbolic"
add "Suspend"     "system-suspend-symbolic"
grep -qw disk /sys/power/state 2>/dev/null && add "Hibernate" "system-hibernate-symbolic"
add "Restart"     "system-reboot-symbolic"
add "Shut Down"   "system-shutdown-symbolic"

MENU_STYLE="listview { lines: ${#labels[@]}; }"

# note: rows must be emitted with printf — bash variables cannot
# hold the NUL byte that separates an entry from its icon metadata
emit() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${icons[$i]}"
    done
}

choice="$(emit \
    | rofi -dmenu -i -p "Session" -theme "$THEME" -theme-str "$MENU_STYLE")"

case "$choice" in
    "Lock Screen") loginctl lock-session ;;
    "Log Out")
        # end the session right away (no Plasma confirmation dialog)
        if [[ -n "${XDG_SESSION_ID:-}" ]]; then
            loginctl terminate-session "$XDG_SESSION_ID"
        else
            qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout
        fi
        ;;
    "Suspend")     systemctl suspend ;;
    "Hibernate")   systemctl hibernate ;;
    "Restart")     systemctl reboot ;;
    "Shut Down")   systemctl poweroff ;;
    *) exit 1 ;;
esac
