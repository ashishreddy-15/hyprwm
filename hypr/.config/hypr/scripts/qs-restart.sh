#!/usr/bin/env bash
# Restart Quickshell (bar, launcher, notifications, OSD, lock screen, ...).
# For when the shell gets into a bad state; a `qs ipc call shell reload` runs
# inside Quickshell, so it can't help when Quickshell itself is stuck.
#
#   qs-restart.sh      Super+Ctrl+R, or "Restart shell" in the power menu (Super+X)
#
# Replaces the restart loop from autostart.lua with a fresh one, so exactly one
# Quickshell comes back. Refuses while Quickshell's lock screen is up: killing
# the lock client would leave Hyprland's "lock died" screen.
set -uo pipefail

if [[ $(timeout 2 qs ipc call lock secure 2>/dev/null) == true ]]; then
    exit 1
fi

# the autostart loop first (it would start a second qs), then Quickshell
pkill -u "$USER" -f '^sh -c until qs; do sleep 1; done$'
pkill -xu "$USER" qs
for _ in $(seq 30); do
    pgrep -xu "$USER" qs >/dev/null || break
    sleep 0.1
done
pkill -9 -xu "$USER" qs   # still there after 3 s: hung

# Detached, so it outlives this script (and Quickshell, when the power menu ran it)
setsid -f sh -c 'until qs; do sleep 1; done' >/dev/null 2>&1 </dev/null
