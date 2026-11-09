#!/usr/bin/env bash
# SDDM login theme "horizon", matching this setup's lock screen and bar.
#
#   theme     setup/sddm/theme/horizon        -> /usr/share/sddm/themes/horizon/
#             + Maple Mono NF ExtraLight/Regular/Medium and the wallpaper
#               (the sddm user can't read ~)
#   drop-in   setup/sddm/20-horizon.conf      -> /etc/sddm.conf.d/20-horizon.conf
#             (switches the theme only; the greeter compositor setup stays
#              with ~/swaywm/setup/sddm.sh and its 10-swaywm.conf)
#
# Usage: setup/sddm.sh [--test] [--dry-run] [--uninstall]
#   --test       preview the theme in a window (no sudo, nothing installed)
#   (no option)  install (asks for sudo); shows at the next login screen
#   --uninstall  remove it; SDDM falls back to the "mono" theme
#
# sddm is not restarted here: that would end the running session.
# If the greeter ever breaks: Ctrl+Alt+F3, log in, then
#   sudo rm /etc/sddm.conf.d/20-horizon.conf && sudo systemctl restart sddm
set -euo pipefail

TEST=0 DRY=0 UNINSTALL=0
for a in "$@"; do
    case "$a" in
        --test)      TEST=1 ;;
        --dry-run)   DRY=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 1 ;;
    esac
done

HERE="$(dirname "$(realpath "$0")")"
SRC="$HERE/sddm"
REPO="$(dirname "$HERE")"
THEME_DIR=/usr/share/sddm/themes/horizon
DROPIN=/etc/sddm.conf.d/20-horizon.conf

run() { if (( DRY )); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

if (( UNINSTALL )); then
    if (( ! DRY )) && [[ $EUID -ne 0 ]]; then exec sudo "$0" "$@"; fi
    echo "==> Removing the horizon SDDM theme"
    run rm -f "$DROPIN"
    run rm -rf "$THEME_DIR"
    echo "==> Done. The previous theme (mono) returns at the next login screen."
    exit 0
fi

# ── Build the theme into a staging dir (as the user: fonts live in ~) ──
build() {  # build DIR
    local out=$1 user_home w font
    user_home="$(getent passwd "${SUDO_USER:-$(id -un)}" | cut -d: -f6)"
    install -d "$out/fonts"
    install -m 644 "$SRC/theme/horizon/"{Main.qml,TextButton.qml,metadata.desktop,theme.conf} "$out/"
    for w in ExtraLight Regular Medium; do
        font=$(find "$user_home/.local/share/fonts" /usr/local/share/fonts /usr/share/fonts \
                    -name "MapleMono-NF-$w.ttf" -print -quit 2>/dev/null || true)
        if [[ -n $font ]]; then install -m 644 "$font" "$out/fonts/"
        else echo "    warning: MapleMono-NF-$w.ttf not found (falls back to a default font)" >&2; fi
    done
    # 2560 px wide is enough for the 27" screen and keeps the theme small
    magick "$REPO/hypr/.config/hypr/wallpaper.jpg" -resize '2560x>' -strip -quality 88 "$out/background.jpg"
}

if (( TEST )); then
    stage=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/horizon-sddm.XXXXXX")
    trap 'rm -rf "$stage"' EXIT
    build "$stage"
    echo 'forceMain="true"' >> "$stage/theme.conf"   # show the form whatever screen the preview lands on
    echo "==> Previewing (close the window to finish)"
    sddm-greeter-qt6 --test-mode --theme "$stage"
    exit 0
fi

command -v sddm-greeter-qt6 >/dev/null || { echo "sddm-greeter-qt6 not found; is sddm installed?" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) is needed to prepare the wallpaper" >&2; exit 1; }
[[ -f /etc/sddm.conf.d/10-swaywm.conf ]] || \
    echo "note: ~/swaywm/setup/sddm.sh hasn't been run; the theme still works with Fedora's stock greeter compositor"

stage=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/horizon-sddm.XXXXXX")
trap 'rm -rf "$stage"' EXIT
echo "==> Building the theme"
build "$stage"

echo "==> Installing (sudo)"
SUDO=sudo; (( EUID == 0 )) && SUDO=
run $SUDO rm -rf "$THEME_DIR"
run $SUDO install -d -m 755 "$THEME_DIR/fonts"
for f in "$stage"/*; do [[ -f $f ]] && run $SUDO install -m 644 "$f" "$THEME_DIR/"; done
for f in "$stage"/fonts/*; do run $SUDO install -m 644 "$f" "$THEME_DIR/fonts/"; done
run $SUDO install -D -m 644 "$SRC/20-horizon.conf" "$DROPIN"
if command -v restorecon >/dev/null; then run $SUDO restorecon -R "$THEME_DIR" "$DROPIN"; fi

echo "==> Done. The horizon login screen appears the next time you log out or reboot."
