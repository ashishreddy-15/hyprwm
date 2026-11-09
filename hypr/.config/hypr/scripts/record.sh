#!/usr/bin/env bash
# Toggle screen recording of a selected area (wf-recorder). Bound to Shift+Print.
# First press: pick an area with slurp and start. Second press: stop and save.
# The bar shows REC in amber while wf-recorder runs.
DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/recordings"
STATE="${XDG_RUNTIME_DIR:-/tmp}/recording.path"

notify() {
    notify-send -a recording -u low -t 3000 \
        -h string:x-dunst-stack-tag:recording "Screen recording" "$1"
}

if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder
    notify "saved: $(cat "$STATE" 2>/dev/null)"
    exit 0
fi

command -v wf-recorder >/dev/null || { notify "wf-recorder is not installed"; exit 1; }

area=$(slurp -d -b 0f110d99 -c db892d -s 00000000 -w 1) || exit 0   # Escape cancels
mkdir -p "$DIR"
file="$DIR/rec-$(date +%Y%m%d-%H%M%S).mp4"
echo "$file" > "$STATE"
notify "recording... press Shift+Print to stop"
exec wf-recorder -g "$area" -f "$file"
