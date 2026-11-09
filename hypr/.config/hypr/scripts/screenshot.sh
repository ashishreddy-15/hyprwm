#!/usr/bin/env bash
# Screenshot → save to the screenshots folder AND copy to the clipboard.
# (grimshot only works on Sway; this does the same with grim + slurp.)
#
#   screenshot.sh output   focused monitor        (Print)
#   screenshot.sh window   focused window         (Alt+Print)
#   screenshot.sh area     select a region        (Ctrl+Print; Escape cancels)
set -euo pipefail

DIR="${XDG_SCREENSHOTS_DIR:-$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots}"
mkdir -p "$DIR"
file="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-output}" in
    output)
        out=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        grim -o "$out" "$file"
        what="Screen"
        ;;
    window)
        geom=$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
        [[ -n "$geom" ]] || { notify-send -u low "Screenshot" "No focused window"; exit 1; }
        grim -g "$geom" "$file"
        what="Window"
        ;;
    area)
        geom=$(slurp -d -b 0f110d99 -c 6fa3b8 -s 00000000 -w 1) || exit 0
        grim -g "$geom" "$file"
        what="Area"
        ;;
    *)
        echo "usage: ${0##*/} output|window|area" >&2
        exit 1
        ;;
esac

wl-copy --type image/png < "$file"
notify-send -a screenshot -u low -i "$file" "$what screenshot" "Saved to ${file/#$HOME/~} and copied"
