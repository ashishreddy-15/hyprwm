#!/usr/bin/env bash
# Idle handling with a "keep awake" switch (Hyprland port of Sway's idle.sh).
#
#   keep-awake.sh start    (re)start hypridle for the current mode (autostart runs this)
#   keep-awake.sh toggle   flip keep-awake on/off and restart hypridle
#   keep-awake.sh status   prints "on" or "off" (the bar shows AWAKE in amber when on)
#
# Normal: hypridle.conf (lock 5 min, screens off 10 min, suspend on battery 15 min).
# Keep awake: hypridle-awake.conf (no timeouts; still locks before sleep).
# The state lives in XDG_RUNTIME_DIR, so it resets at the next login.
# Separate from Sway's flag file, so the two sessions never affect each other.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-keep-awake"
CONF="$HOME/.config/hypr"

start() {
    pkill -xu "$USER" hypridle || true
    if [[ -e $STATE ]]; then
        setsid -f hypridle -q -c "$CONF/hypridle-awake.conf"
    else
        setsid -f hypridle -q -c "$CONF/hypridle.conf"
    fi
}

case ${1:-} in
    start)  start ;;
    toggle)
        if [[ -e $STATE ]]; then rm -f "$STATE"; else touch "$STATE"; fi
        start
        ;;
    status) [[ -e $STATE ]] && echo on || echo off ;;
    *)
        echo "usage: ${0##*/} start|toggle|status" >&2
        exit 1
        ;;
esac
