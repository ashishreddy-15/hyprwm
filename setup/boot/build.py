#!/usr/bin/env python3
"""Build the Horizon boot themes (GRUB + Plymouth) into a staging directory.

    build.py OUT WALLPAPER FONT_DIR

OUT/grub/horizon/      theme.txt, background, line pieces, Maple Mono .pf2 fonts
OUT/plymouth/horizon/  horizon.plymouth, horizon.script, wallpaper, line/glow/text PNGs

Every word shown at boot is drawn here from Maple Mono, so neither GRUB nor
the initramfs needs the font except as GRUB's bitmap .pf2. Runs as the user
(the font and wallpaper live in ~); setup/boot.sh installs the result.
Needs: python3-pillow, grub2-mkfont (grub2-tools-extra / grub2-tools).
"""
import math
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent

# Horizon palette (quickshell Theme.qml / ~/swaywm/colors.md)
GROUND = (0x13, 0x16, 0x0F)
DIM    = (0x5A, 0x61, 0x52)
MUTED  = (0x8C, 0x93, 0x84)
FG     = (0xE6, 0xE8, 0xE1)
ACCENT = (0x6F, 0xA3, 0xB8)
RED    = (0xE0, 0x55, 0x55)
AMBER  = (0xDB, 0x89, 0x2D)

HORIZON = 0.528   # the photo's horizon, as a fraction of its height (measured)


def rgba(c, a=1.0):
    return (c[0], c[1], c[2], round(255 * a))


def blank(path, size=(1, 1), color=(0, 0, 0, 0)):
    Image.new("RGBA", size, color).save(path)


def hline(path, width, color, halo=0.25):
    """The horizon line: 5 px tall, a 1 px core on row 2 and a soft halo,
    fading to nothing at both ends (as in Lock.qml)."""
    im = Image.new("RGBA", (width, 5))
    px = im.load()
    for x in range(width):
        t = x / (width - 1)
        a = 1 - abs(t - 0.5) * 2          # 0 → 1 → 0
        for y in range(5):
            px[x, y] = rgba(color, a * (1.0 if y == 2 else halo))
    im.save(path)


def text(path, s, size, color, font, spacing=0.0):
    """Text as an image, drawn a character at a time so letter spacing
    matches the Quickshell screens."""
    f = ImageFont.truetype(str(font), size)
    adv = f.getlength("M")
    asc, desc = f.getmetrics()
    w = math.ceil(adv * len(s) + spacing * (len(s) - 1)) + 2
    mask = Image.new("L", (w, asc + desc + 2))
    d = ImageDraw.Draw(mask)
    x = 1
    for ch in s:
        d.text((x, 1), ch, font=f, fill=255)
        x += adv + spacing
    im = Image.new("RGBA", mask.size, rgba(color))
    im.putalpha(mask)
    im.save(path)


def glow(path, w=420, h=14):
    """The point of light that runs along the horizon: a flattened ellipse,
    white-hot in the middle, warm at the edges."""
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            r = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            if r >= 1:
                continue
            if r < 0.28:
                k = r / 0.28
                c = tuple(round(a + (b - a) * k) for a, b in zip((255, 246, 228), (255, 226, 180)))
                al = 0.95 + (0.35 - 0.95) * k
            else:
                k = (r - 0.28) / 0.72
                c = tuple(round(a + (b - a) * k) for a, b in zip((255, 226, 180), (255, 210, 150)))
                al = 0.35 * (1 - k) ** 1.5
            px[x, y] = (*c, round(255 * al))
    im.save(path)


def trail(path, w=512):
    """The lit stretch of horizon behind the light: transparent → bright."""
    im = Image.new("RGBA", (w, 1))
    for x in range(w):
        im.putpixel((x, 0), rgba(FG, 0.55 * x / (w - 1)))
    im.save(path)


def grub(out, wallpaper, fonts):
    out.mkdir(parents=True, exist_ok=True)
    # 1920×1200 is the laptop panel; GRUB crops for other modes
    src = Image.open(wallpaper).convert("RGB")
    s = max(1920 / src.width, 1200 / src.height)
    im = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    l, t = (im.width - 1920) // 2, (im.height - 1200) // 2
    im.crop((l, t, l + 1920, t + 1200)).save(out / "background.png", optimize=True)

    # selected entry: the horizon line in the south slice (under the text);
    # the corners set the text inset (28 px); the centre stays clear
    hline(out / "select_s.png", 720, ACCENT)
    blank(out / "select_sw.png", (28, 5))
    blank(out / "select_se.png", (28, 5))
    blank(out / "select_c.png")
    # countdown line: only the shrinking highlight is drawn
    # (GRUB gives the bar a taller box than asked for, so the line is drawn
    # into a 24 px tall piece at row 12 instead of filling the whole box)
    blank(out / "timeout_bar_c.png", (1, 24))
    hl = Image.new("RGBA", (1, 24))
    hl.putpixel((0, 12), rgba(ACCENT, 0.85))
    hl.save(out / "timeout_hl_c.png")
    # e (edit) and c (console) screens: a dark panel over the photo
    Image.new("RGBA", (1, 1), rgba(GROUND, 0.94)).save(out / "terminal_c.png")

    regular = fonts / "MapleMono-Regular.ttf"
    for size in (15, 17, 19):
        subprocess.run(
            ["grub2-mkfont", "-s", str(size),
             "-r", "0x20-0x7E,0xA0-0xFF,0x2010-0x2027,0x2190-0x2193,0x2500-0x257F",
             "-o", str(out / f"maple-{size}.pf2"), str(regular)],
            check=True, stderr=subprocess.DEVNULL)

    # key hints, keys a shade brighter: one label per run of colour,
    # placed by hand (monospace: 9 px per character at 15 px)
    adv = 9
    runs = [("↑↓", MUTED), (" choose · ", DIM), ("enter", MUTED), (" start · ", DIM),
            ("e", MUTED), (" edit · ", DIM), ("c", MUTED), (" console", DIM)]
    total = sum(len(s) for s, _ in runs) * adv
    x = -total // 2
    labels = []
    for s, c in runs:
        off = f"50%{x:+d}"
        labels.append(
            "+ label {\n"
            f"    left = {off}\n    top = 100%-70\n    width = {len(s) * adv + adv}\n    height = 22\n"
            f'    font = "Maple Mono Regular 15"\n    color = "#{c[0]:02x}{c[1]:02x}{c[2]:02x}"\n'
            f'    text = "{s}"\n}}')
        x += len(s) * adv
    theme = (HERE / "grub" / "theme.txt").read_text().replace("@HINTS@", "\n".join(labels))
    (out / "theme.txt").write_text(theme)


def plymouth(out, wallpaper, fonts):
    out.mkdir(parents=True, exist_ok=True)
    for f in ("horizon.plymouth", "horizon.script"):
        shutil.copy(HERE / "plymouth" / f, out / f)
    # full 3:2 photo, 1920 wide: covers 16:10 and 16:9 screens; the script crops
    src = Image.open(wallpaper).convert("RGB")
    src.resize((1920, round(src.height * 1920 / src.width)), Image.LANCZOS).save(out / "wallpaper.png", optimize=True)

    hline(out / "line-accent.png", 340, ACCENT)
    hline(out / "line-red.png", 340, RED)
    glow(out / "glow.png")
    trail(out / "trail.png")

    reg = fonts / "MapleMono-Regular.ttf"
    text(out / "dot.png", "•", 18, FG, reg)
    text(out / "t-who.png", "disk passphrase", 14, DIM, reg, 2)
    text(out / "t-type.png", "type to unlock", 15, DIM, reg)
    text(out / "t-checking.png", "checking…", 15, DIM, reg)
    text(out / "t-wrong.png", "wrong passphrase", 12, RED, reg, 1.5)
    text(out / "t-caps.png", "CAPS LOCK", 12, AMBER, reg, 1.5)
    text(out / "t-shutdown.png", "SHUTTING DOWN", 14, MUTED, reg, 4)
    text(out / "t-restart.png", "RESTARTING", 14, MUTED, reg, 4)
    text(out / "t-update.png", "UPDATING", 14, MUTED, reg, 4)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    out, wallpaper, fonts = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    if not (fonts / "MapleMono-Regular.ttf").is_file():
        sys.exit(f"MapleMono-Regular.ttf not found in {fonts}")
    grub(out / "grub" / "horizon", wallpaper, fonts)
    plymouth(out / "plymouth" / "horizon", wallpaper, fonts)


if __name__ == "__main__":
    main()
