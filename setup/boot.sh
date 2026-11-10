#!/usr/bin/env bash
# Horizon boot themes: the GRUB menu and the Plymouth splash (disk passphrase),
# matching the lock screen and the SDDM login.
#
#   GRUB      setup/boot/grub      -> /boot/grub2/themes/horizon/
#                                     + /boot/grub2/custom.cfg (switches it on)
#             Fedora's grub.cfg sources custom.cfg, so grub2-mkconfig is never
#             run and the boot entries (Fedora, Windows) are left as they are.
#   Plymouth  setup/boot/plymouth  -> /usr/share/plymouth/themes/horizon/
#             made the default with plymouth-set-default-theme -R (rebuilds
#             the initramfs of the running kernel; later kernels get it too).
#             Needs plymouth-plugin-script (Fedora repo).
#
# Usage: setup/boot.sh [--only grub|plymouth] [--dry-run] [--test] [--preview-grub] [--uninstall]
#   (no option)     build and install both (asks for sudo); first takes a
#                   snapper snapshot of / and keeps a copy of the running
#                   kernel's initramfs as /boot/initramfs-<version>.img.pre-horizon
#   --only X        just the GRUB menu or just the Plymouth splash
#   --dry-run       show what would be installed, change nothing
#   --test          preview the Plymouth splash (sudo, from a text console:
#                   Ctrl+Alt+F3). Type anything at the prompts; the second
#                   prompt shows the "wrong passphrase" state. Then shutdown.
#   --preview-grub  show the GRUB menu in a QEMU window (no sudo; needs
#                   qemu-system-x86-core and edk2-ovmf from Fedora's repo)
#   --uninstall     back to Fedora's defaults: the text menu and "bgrt"
#
# If boot ever goes wrong: a broken GRUB theme falls back to the text menu.
# A broken splash falls back to a text passphrase prompt (Esc shows it any
# time). Last resort: in GRUB press e, delete "rhgb quiet", Ctrl+X, then
# run setup/boot.sh --uninstall.
set -euo pipefail

ONLY="" DRY=0 TEST=0 PREVIEW=0 UNINSTALL=0
while (( $# )); do
    case "$1" in
        --only)          ONLY=${2:-}; shift
                         [[ $ONLY == grub || $ONLY == plymouth ]] || { echo "--only takes grub or plymouth" >&2; exit 1; } ;;
        --dry-run)       DRY=1 ;;
        --test)          TEST=1 ;;
        --preview-grub)  PREVIEW=1 ;;
        --uninstall)     UNINSTALL=1 ;;
        -h|--help)       sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
want() { [[ -z $ONLY || $ONLY == "$1" ]]; }

HERE="$(dirname "$(realpath "$0")")"
REPO="$(dirname "$HERE")"
GRUB_DIR=/boot/grub2
GRUB_THEME=$GRUB_DIR/themes/horizon
GRUB_CUSTOM=$GRUB_DIR/custom.cfg
PLY_THEME=/usr/share/plymouth/themes/horizon
MARK="Horizon boot menu"          # first line of our custom.cfg

SUDO=sudo; (( EUID == 0 )) && SUDO=
run() { if (( DRY )); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

user_home="$(getent passwd "${SUDO_USER:-$(id -un)}" | cut -d: -f6)"
build() {  # build OUT
    local fonts
    fonts=$(dirname "$(find "$user_home/.local/share/fonts" /usr/local/share/fonts /usr/share/fonts \
                  -name MapleMono-Regular.ttf -print -quit 2>/dev/null)")
    python3 "$HERE/boot/build.py" "$1" "$REPO/hypr/.config/hypr/wallpaper.jpg" "$fonts"
}
stage=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/horizon-boot.XXXXXX")
trap 'rm -rf "$stage"' EXIT

# ── uninstall ──
if (( UNINSTALL )); then
    if want grub; then
        echo "==> GRUB: back to the text menu"
        if $SUDO test -f "$GRUB_CUSTOM"; then
            if $SUDO head -1 "$GRUB_CUSTOM" | grep -q "$MARK"; then run $SUDO rm -f "$GRUB_CUSTOM"
            else echo "    $GRUB_CUSTOM isn't ours; left alone"; fi
        fi
        run $SUDO rm -rf "$GRUB_THEME"
    fi
    if want plymouth; then
        echo "==> Plymouth: back to bgrt (rebuilds the initramfs, takes a minute)"
        if [[ $(plymouth-set-default-theme) == horizon ]]; then run $SUDO plymouth-set-default-theme -R bgrt; fi
        run $SUDO rm -rf "$PLY_THEME"
    fi
    echo "==> Done."
    exit 0
fi

for tool in python3 grub2-mkfont; do
    command -v $tool >/dev/null || { echo "$tool is needed" >&2; exit 1; }
done
python3 -c 'import PIL' 2>/dev/null || { echo "python3-pillow is needed: sudo dnf install python3-pillow" >&2; exit 1; }
echo "==> Building"
build "$stage"

# ── GRUB preview in QEMU (no sudo, nothing installed) ──
if (( PREVIEW )); then
    command -v qemu-system-x86_64 >/dev/null && [[ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]] || {
        echo "needs: sudo dnf install qemu-system-x86-core edk2-ovmf" >&2; exit 1; }
    # Fedora's own GRUB binary, taken from the package (the installed copies
    # under /boot/efi and /usr/lib/efi are readable by root only)
    ( cd "$stage" && dnf download -q grub2-efi-x64 >/dev/null \
        && rpm2cpio grub2-efi-x64-*.rpm | cpio -id --quiet '*/EFI/fedora/grubx64.efi' )
    grub_efi=$(find "$stage" -name grubx64.efi -print -quit)
    [[ -n $grub_efi ]] || { echo "couldn't get grubx64.efi from the grub2-efi-x64 package" >&2; exit 1; }
    esp="$stage/esp"
    install -d "$esp/EFI/BOOT" "$esp/EFI/fedora/themes"
    cp "$grub_efi" "$esp/EFI/BOOT/BOOTX64.EFI"
    cp -r "$stage/grub/horizon" "$esp/EFI/fedora/themes/"
    cp "$HERE/boot/grub/custom.cfg" "$esp/EFI/fedora/custom.cfg"
    {   # stand-in entries named like this machine's (the real list needs root to read)
        echo 'set timeout=5'
        echo 'set default=0'
        for k in $(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -rV); do
            echo "menuentry 'Fedora Linux ($k) $(. /etc/os-release; echo "$VERSION")' { echo booting; sleep 2; }"
        done
        echo "menuentry 'Windows Boot Manager' { echo windows; sleep 2; }"
        echo "menuentry 'UEFI Firmware Settings' { fwsetup; }"
        echo 'source ${config_directory}/custom.cfg'
    } > "$esp/EFI/fedora/grub.cfg"
    # GRUB may read its config next to itself (EFI/BOOT) or from its prefix (EFI/fedora)
    cp -r "$esp/EFI/fedora/themes" "$esp/EFI/fedora/custom.cfg" "$esp/EFI/fedora/grub.cfg" "$esp/EFI/BOOT/"
    cp /usr/share/edk2/ovmf/OVMF_VARS.fd "$stage/vars.fd"
    qemu=(qemu-system-x86_64 -machine q35 -m 512 -vga std -net none
          -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd
          -drive if=pflash,format=raw,file="$stage/vars.fd"
          -drive format=raw,file=fat:rw:"$esp")
    [[ -r /dev/kvm && -w /dev/kvm ]] && qemu+=(-enable-kvm)
    if qemu-system-x86_64 -display help | grep -qx gtk; then
        echo "==> GRUB preview (close the window to finish)"
        "${qemu[@]}" -display gtk,zoom-to-fit=on
    else
        # no window support (qemu-ui-gtk isn't installed): screenshots instead
        shots="${XDG_RUNTIME_DIR:-/tmp}/horizon-grub-preview"
        rm -rf "$shots"
        echo "==> GRUB preview as screenshots in $shots (for a window: sudo dnf install qemu-ui-gtk)"
        "${qemu[@]}" -display none -monitor unix:"$stage/mon.sock",server,nowait &
        python3 "$HERE/boot/grub-shots.py" "$stage/mon.sock" "$shots"
        wait
    fi
    exit 0
fi

# ── Plymouth preview, from a text console ──
if (( TEST )); then
    # the splash needs the screen: run from a text console, not inside the desktop
    if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
        echo "Run this from a text console: Ctrl+Alt+F3, log in, then ~/hyprwm/setup/boot.sh --test" >&2
        echo "(the desktop owns the screen otherwise). Ctrl+Alt+F1 or F2 brings the desktop back." >&2
        exit 1
    fi
    rpm -q plymouth-plugin-script >/dev/null || { echo "needs: sudo dnf install plymouth-plugin-script" >&2; exit 1; }
    prev=$(plymouth-set-default-theme)
    had_theme=0; [[ -d $PLY_THEME ]] && had_theme=1
    $SUDO install -d -m 755 "$PLY_THEME"
    $SUDO install -m 644 "$stage/plymouth/horizon/"* "$PLY_THEME/"
    $SUDO plymouth-set-default-theme horizon        # config only; no initramfs rebuild
    restore() {
        $SUDO plymouth --quit 2>/dev/null || true
        $SUDO plymouth-set-default-theme "$prev"
        (( had_theme )) || $SUDO rm -rf "$PLY_THEME"
        rm -rf "$stage"
    }
    trap restore EXIT
    tty_name=$(cat /sys/class/tty/tty0/active)    # the console on screen, e.g. tty3
    $SUDO plymouthd --mode=boot --tty="$tty_name" --no-boot-log
    $SUDO plymouth show-splash
    sleep 2
    $SUDO plymouth ask-for-password --prompt "Preview: type anything" >/dev/null || true
    sleep 1.5
    $SUDO plymouth ask-for-password --prompt "Preview: type anything" >/dev/null || true
    $SUDO plymouth update-root-fs --new-root-dir=/
    $SUDO plymouth display-message --text="preview · nothing was unlocked"
    sleep 7
    $SUDO plymouth quit
    sleep 1
    $SUDO plymouthd --mode=shutdown --tty="$tty_name" --no-boot-log
    $SUDO plymouth show-splash
    sleep 6
    $SUDO plymouth quit
    echo "==> Preview finished; the theme setting is back to \"$prev\"."
    exit 0
fi

# ── install ──
# Safety copies first. snapper snapshots / (btrfs) — that covers
# /usr/share/plymouth and /etc/plymouth. /boot is a separate partition and
# isn't in the snapshot, so the running kernel's initramfs (rebuilt by the
# splash install) is copied aside there once, and kept.
backup() {
    echo "==> Safety copies"
    if command -v snapper >/dev/null && $SUDO snapper -c root list >/dev/null 2>&1; then
        if (( DRY )); then echo "    [dry-run] snapper -c root create --description 'before Horizon boot themes'"
        else
            num=$($SUDO snapper -c root create --cleanup-algorithm number --print-number \
                    --description "before Horizon boot themes")
            echo "    snapper snapshot #$num of /   (see: sudo snapper -c root status $num..0)"
        fi
    else
        echo "    no snapper \"root\" config; no snapshot taken" >&2
    fi
    if want plymouth; then
        local img=/boot/initramfs-$(uname -r).img
        if $SUDO test -f "$img.pre-horizon"; then echo "    $img.pre-horizon already kept from an earlier install"
        else run $SUDO cp -a "$img" "$img.pre-horizon" && echo "    copied $img to $img.pre-horizon"; fi
    fi
}
backup

if want grub; then
    echo "==> GRUB menu"
    $SUDO grep -q 'custom.cfg' "$GRUB_DIR/grub.cfg" || {
        echo "    $GRUB_DIR/grub.cfg doesn't load custom.cfg; skipping GRUB (nothing changed)" >&2; ONLY=plymouth; }
    if want grub && $SUDO test -f "$GRUB_CUSTOM" && ! $SUDO head -1 "$GRUB_CUSTOM" | grep -q "$MARK"; then
        echo "    $GRUB_CUSTOM already exists and isn't ours; skipping GRUB (nothing changed)" >&2; ONLY=plymouth
    fi
fi
if want grub; then
    run $SUDO rm -rf "$GRUB_THEME"
    run $SUDO install -d -m 755 "$GRUB_THEME"
    run $SUDO install -m 644 "$stage/grub/horizon/"* "$GRUB_THEME/"
    run $SUDO install -m 644 "$HERE/boot/grub/custom.cfg" "$GRUB_CUSTOM"
    if command -v restorecon >/dev/null; then run $SUDO restorecon -R "$GRUB_THEME" "$GRUB_CUSTOM"; fi
    echo "    installed; shows at the next boot"
fi

if want plymouth; then
    echo "==> Plymouth splash"
    if ! rpm -q plymouth-plugin-script >/dev/null; then
        echo "    needs: sudo dnf install plymouth-plugin-script   (skipped, nothing changed)" >&2
    else
        run $SUDO rm -rf "$PLY_THEME"
        run $SUDO install -d -m 755 "$PLY_THEME"
        run $SUDO install -m 644 "$stage/plymouth/horizon/"* "$PLY_THEME/"
        if command -v restorecon >/dev/null; then run $SUDO restorecon -R "$PLY_THEME"; fi
        echo "    rebuilding the initramfs (takes a minute)"
        run $SUDO plymouth-set-default-theme -R horizon
    fi
fi
echo "==> Done."
