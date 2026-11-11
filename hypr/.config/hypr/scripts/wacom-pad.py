#!/usr/bin/env python3
"""Wacom Intuos pad buttons -> keyboard shortcuts, per application.

Hyprland has no bindings for tablet pad buttons, so this small daemon reads the
pad (/dev/input, via python-evdev), asks Hyprland which window is focused, and
types the shortcut you chose through a virtual keyboard (/dev/uinput).

  Needs: python3-evdev, and the udev rule in /etc/udev/rules.d/70-wacom-pad.rules
         (see the README, "Wacom tablet"). Started from modules/autostart.lua.

  Usage:
    wacom-pad.py           run the daemon (what autostart does)
    wacom-pad.py learn     print every pad button you press together with the
                           focused window's class and title, to help write
                           the PROFILES below. Stop with Ctrl+C.

HOW TO CHANGE THE BUTTONS: edit the PROFILES block below, nothing else. Then
restart the daemon:   pkill -f wacom-pad.py; ~/.config/hypr/scripts/wacom-pad.py &
(The script runs from the stowed symlink, so editing the repo file is enough.)
"""

import json
import re
import subprocess
import sys
import time

import evdev
from evdev import UInput, ecodes

# ═════════════════════════ SETTINGS — EDIT THIS PART ═════════════════════════

# Name of the pad as the kernel reports it (see `learn`, or
# `grep -r . /sys/class/input/event*/device/name`). It is the same over USB and
# Bluetooth. Matched as a substring, so "Intuos" would also be fine.
PAD_NAME = "Wacom Intuos BT S Pad"

# The four express keys, top to bottom (as on the Intuos BT S). If you ever get
# a different tablet, run `learn` and add the codes it prints.
#   1 = BTN_0   2 = BTN_1   3 = BTN_2   4 = BTN_3
BUTTON_CODES = {
    "BTN_0": 1,
    "BTN_1": 2,
    "BTN_2": 3,
    "BTN_3": 4,
}

# Profiles decide what each button does. They are checked top to bottom and ALL
# matching profiles apply; a later profile overrides an earlier one for the
# buttons it defines. So: put the everywhere-defaults first, specifics after.
#
#   "class"  regex matched against the focused window's class (case-insensitive).
#            Omit it to match any window. Find it with `learn` or
#            `hyprctl activewindow | grep class`.
#   "title"  regex matched against the window title (case-insensitive). Optional.
#   "keys"   {button number: shortcut}. A shortcut is "key" or "mod+mod+key":
#              "ctrl+z"   "ctrl+shift+z"   "e"   "f5"   "super+shift+s"
#            Modifiers: ctrl, shift, alt, super.  Keys: a-z, 0-9, f1-f12, space,
#            enter, esc, tab, backspace, delete, left/right/up/down, home/end,
#            pageup/pagedown, or any evdev name such as "KEY_BRIGHTNESSUP".
#            The key is held while you hold the pad button (so "space" in
#            Excalidraw = hold to pan). A button with no entry does nothing.
#            A value starting with "!" runs a shell command instead (once, on
#            press): "!playerctl play-pause"   "!playerctl position 10-"
PROFILES = [
    # Everywhere: undo, and play/pause for whatever media is playing.
    {
        "keys": {
            1: "ctrl+z",
            2: "!playerctl play-pause",   # pause/play the video without leaving the notes
        },
    },
    # Only on an Excalidraw drawing in Obsidian: eraser and pen tool. The
    # title check matters: in a normal note these would type the letters "e"/"p".
    # Excalidraw files show up in Obsidian's window title as "<name>.excalidraw".
    {
        "class": r"obsidian",   # Flatpak reports "md.obsidian.Obsidian"
        "title": r"\.excalidraw",
        "keys": {
            3: "e",   # eraser
            4: "p",   # pen (draw)
        },
    },
]

# ═══════════════════════════ END OF SETTINGS ═════════════════════════════════

MODIFIERS = {
    "ctrl": "KEY_LEFTCTRL", "shift": "KEY_LEFTSHIFT",
    "alt": "KEY_LEFTALT", "super": "KEY_LEFTMETA",
}
ALIASES = {
    "esc": "KEY_ESC", "enter": "KEY_ENTER", "space": "KEY_SPACE", "tab": "KEY_TAB",
    "backspace": "KEY_BACKSPACE", "delete": "KEY_DELETE", "home": "KEY_HOME",
    "end": "KEY_END", "pageup": "KEY_PAGEUP", "pagedown": "KEY_PAGEDOWN",
    "left": "KEY_LEFT", "right": "KEY_RIGHT", "up": "KEY_UP", "down": "KEY_DOWN",
}


def is_command(text):
    return text.startswith("!")


def parse_shortcut(text):
    """'ctrl+shift+z' -> [KEY_LEFTCTRL, KEY_LEFTSHIFT, KEY_Z] (evdev codes)."""
    codes = []
    for part in (p.strip().lower() for p in text.split("+")):
        name = MODIFIERS.get(part) or ALIASES.get(part)
        if name is None:
            name = part.upper() if part.upper().startswith("KEY_") else "KEY_" + part.upper()
        if name not in ecodes.ecodes:
            raise ValueError(f"unknown key {part!r} in shortcut {text!r}")
        codes.append(ecodes.ecodes[name])
    return codes


def focused_window():
    """(class, title) of the focused window, or ('', '') if there is none."""
    try:
        out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True,
                             text=True, timeout=2).stdout
        w = json.loads(out) if out.strip() else {}
    except (OSError, subprocess.SubprocessError, ValueError):
        return "", ""
    return w.get("class", "") or "", w.get("title", "") or ""


def shortcut_for(button, win_class, win_title):
    """Resolve a pad button to a shortcut string using PROFILES, or None."""
    result = None
    for p in PROFILES:
        if "class" in p and not re.search(p["class"], win_class, re.I):
            continue
        if "title" in p and not re.search(p["title"], win_title, re.I):
            continue
        if button in p.get("keys", {}):
            result = p["keys"][button]
    return result


def code_name(code):
    """evdev code -> its name. Some codes have aliases and come back as a
    tuple/list (BTN_0 is ('BTN_0', 'BTN_MISC')); the first name is the one we use."""
    name = ecodes.BTN.get(code) or ecodes.KEY.get(code) or str(code)
    return name[0] if isinstance(name, (list, tuple)) else name


def find_pad():
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        if PAD_NAME in dev.name:
            return dev
        dev.close()
    return None


def learn():
    print(f"Waiting for the pad ({PAD_NAME!r}); press its buttons. Ctrl+C to stop.")
    while True:
        dev = find_pad()
        if dev is None:
            time.sleep(2)
            continue
        print(f"Reading {dev.name} at {dev.path}")
        try:
            for ev in dev.read_loop():
                if ev.type == ecodes.EV_KEY and ev.value == 1:
                    code = code_name(ev.code)
                    cls, title = focused_window()
                    print(f"{code}  (button {BUTTON_CODES.get(code, '?')})  class={cls!r}  title={title!r}")
        except OSError:
            print("Pad went away, waiting for it to come back")


def run():
    # Validate every shortcut now so a typo fails loudly at startup.
    for p in PROFILES:
        for s in p.get("keys", {}).values():
            if not is_command(s):
                parse_shortcut(s)

    wanted = {c for p in PROFILES for s in p.get("keys", {}).values()
              if not is_command(s) for c in parse_shortcut(s)}
    ui = UInput({ecodes.EV_KEY: sorted(wanted)}, name="Wacom pad shortcuts")
    held = {}  # pad button number -> key codes currently held down for it

    def release_all():
        for codes in held.values():
            for c in reversed(codes):
                ui.write(ecodes.EV_KEY, c, 0)
        if held:
            ui.syn()
        held.clear()

    try:
        while True:
            dev = find_pad()
            if dev is None:          # pad off / out of range: poll until it returns
                time.sleep(2)
                continue
            try:
                for ev in dev.read_loop():
                    if ev.type != ecodes.EV_KEY:
                        continue
                    button = BUTTON_CODES.get(code_name(ev.code))
                    if button is None:
                        continue
                    if ev.value == 1:                          # pressed
                        shortcut = shortcut_for(button, *focused_window())
                        if not shortcut:
                            continue
                        if is_command(shortcut):               # "!cmd": run it once
                            subprocess.Popen(shortcut[1:], shell=True, start_new_session=True,
                                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                             stderr=subprocess.DEVNULL)
                            continue
                        codes = parse_shortcut(shortcut)
                        held[button] = codes
                        for c in codes:
                            ui.write(ecodes.EV_KEY, c, 1)
                        ui.syn()
                    elif ev.value == 0 and button in held:     # released
                        for c in reversed(held.pop(button)):
                            ui.write(ecodes.EV_KEY, c, 0)
                        ui.syn()
            except OSError:
                release_all()        # pad disconnected mid-press: don't leave keys stuck
            finally:
                dev.close()
    finally:
        release_all()
        ui.close()


if __name__ == "__main__":
    try:
        learn() if sys.argv[1:] == ["learn"] else run()
    except KeyboardInterrupt:
        pass
