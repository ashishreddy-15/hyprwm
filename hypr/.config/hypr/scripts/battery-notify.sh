#!/usr/bin/env bash
# Warn once at 15% and again at 5% while discharging; resets when plugged in.
# Started once from autostart.lua; flock keeps it to a single instance.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/battery-notify.lock"
flock -n 9 || exit 0

BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[[ -n "$BAT" ]] || exit 0
WARN=15
CRIT=5
level=0   # 0 = nothing sent, 1 = warning sent, 2 = critical sent

while :; do
    cap=$(<"$BAT/capacity")
    status=$(<"$BAT/status")
    if [[ "$status" != "Discharging" ]]; then
        level=0
    elif (( cap <= CRIT && level < 2 )); then
        notify-send -a battery -u critical -h string:x-dunst-stack-tag:battery \
            "Battery critical" "${cap}% left, plug in now"
        level=2
    elif (( cap <= WARN && level < 1 )); then
        notify-send -a battery -u normal -h string:x-dunst-stack-tag:battery \
            "Battery low" "${cap}% left"
        level=1
    fi
    sleep 60
done
