#!/usr/bin/env bash
# Toggle a constant warm screen tint (hyprsunset). Bound to Super+N.
# Same temperature as Sway's wlsunset setup; no sunrise/sunset schedule.
TEMP=4500

notify() {
    notify-send -a nightlight -u low -t 1500 \
        -h string:x-dunst-stack-tag:nightlight "Night light" "$1"
}

if pgrep -xu "$USER" hyprsunset >/dev/null; then
    pkill -xu "$USER" hyprsunset
    notify "off"
else
    setsid -f hyprsunset -t "$TEMP" >/dev/null 2>&1
    notify "on (${TEMP}K)"
fi
