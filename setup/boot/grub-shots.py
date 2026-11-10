#!/usr/bin/env python3
"""Screenshot a headless QEMU through its monitor socket, for the GRUB preview
when QEMU has no window support (qemu-ui-gtk / qemu-ui-sdl not installed).

    grub-shots.py MONITOR_SOCKET OUT_DIR

Shots: the menu while the countdown runs, after ↓ (countdown stopped),
the e (edit) screen and the c (console) screen. Then QEMU quits.
"""
import socket
import sys
import time
from pathlib import Path

sock_path, out = sys.argv[1], Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

for _ in range(100):                      # wait for QEMU to open the socket
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect(sock_path)
        break
    except OSError:
        time.sleep(0.1)
else:
    sys.exit("QEMU monitor didn't come up")
s.settimeout(0.3)


def cmd(c, wait=0.3):
    s.sendall((c + "\n").encode())
    time.sleep(wait)
    try:
        while s.recv(65536):
            pass
    except OSError:
        pass


def shot(name):
    cmd(f"screendump {out / name}.png -f png", 0.6)
    print(out / f"{name}.png")


cmd("info status")
for i in range(1, 7):                     # firmware → GRUB → countdown
    time.sleep(1)
    shot(f"menu-{i}s")
cmd("sendkey down", 0.8)
shot("menu-down")
cmd("sendkey e", 1.0)
shot("edit")
cmd("sendkey esc", 0.8)
cmd("sendkey c", 1.0)
shot("console")
cmd("quit")
