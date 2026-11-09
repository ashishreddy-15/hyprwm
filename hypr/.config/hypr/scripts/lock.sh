#!/usr/bin/env bash
# Lock the session: Quickshell's lock screen, with hyprlock as the fallback.
#
#   lock.sh          lock; returns once the lock is confirmed (so suspend never
#                    runs before the screen is locked)
#   lock.sh status   exit 0 when locked (by either), 1 when not
#
# hypridle's lock_cmd runs this (Super+Shift+Escape, idle lock, before sleep).
# If Quickshell isn't running or can't lock within ~3 s, hyprlock locks instead.
# If everything breaks: Ctrl+Alt+F3, log in, then
#   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'

locked() {
    pgrep -xu "$USER" hyprlock >/dev/null && return 0
    [[ $(qs ipc call lock secure 2>/dev/null) == true ]]
}

[[ ${1:-} == status ]] && { locked; exit $?; }

locked && exit 0

if qs ipc call lock lock >/dev/null 2>&1; then
    for _ in $(seq 20); do
        locked && exit 0
        sleep 0.15
    done
fi

# Quickshell didn't lock: hyprlock does (blocks until unlocked, like before)
pgrep -xu "$USER" hyprlock >/dev/null || exec hyprlock
