#!/usr/bin/env python3
"""Night light that follows the sun (Hyprland, via hyprsunset).

    nightlight.py daemon          apply the schedule every 30 s (autostart)
    nightlight.py toggle          flip the colour now (Super+N); the override
                                  lasts until the next sunrise or sunset
    nightlight.py status          sunrise, sunset and the target right now
    nightlight.py status --at HH:MM   the same for another time today

Schedule (local time), warm = 4500 K, day = no filter:
    before sunrise        warm
    sunrise → +30 min     fades back to day
    day                   no filter
    sunset −60 min → sunset   warms up gradually
    after sunset          warm
"""
import datetime as dt
import fcntl
import json
import math
import os
import subprocess
import sys
import time
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Asia/Kolkata")
LAT, LON = 21.0, 79.0          # central India: an estimate; set your city here
DAY_K, WARM_K = 6500, 4500
FADE_OUT_MIN = 30              # after sunrise, back to day
WARM_UP_MIN = 60               # before sunset, towards warm

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
OVERRIDE = os.path.join(RUN, "nightlight-override.json")
LOCK = os.path.join(RUN, "nightlight.lock")


def sun_times(day):
    """Sunrise and sunset on `day` (a date), as aware local datetimes (NOAA approximation)."""
    n = day.timetuple().tm_yday
    g = 2 * math.pi / 365 * (n - 1)
    eqt = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g)
                    - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g))
    dec = (0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g)
           - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g)
           - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g))
    lat = math.radians(LAT)
    c = (math.cos(math.radians(90.833)) - math.sin(lat) * math.sin(dec)) / (math.cos(lat) * math.cos(dec))
    ha = math.degrees(math.acos(max(-1.0, min(1.0, c))))
    base = dt.datetime(day.year, day.month, day.day, tzinfo=dt.timezone.utc)
    rise = base + dt.timedelta(minutes=720 - 4 * (LON + ha) - eqt)
    sset = base + dt.timedelta(minutes=720 - 4 * (LON - ha) - eqt)
    return rise.astimezone(TZ), sset.astimezone(TZ)


def target_k(now):
    """Colour temperature the schedule wants at `now`."""
    rise, sset = sun_times(now.date())
    fade = dt.timedelta(minutes=FADE_OUT_MIN)
    warm_up = dt.timedelta(minutes=WARM_UP_MIN)
    if now < rise:
        return WARM_K
    if now < rise + fade:
        f = (now - rise) / fade
        return WARM_K + (DAY_K - WARM_K) * f
    if now < sset - warm_up:
        return DAY_K
    if now < sset:
        f = (now - (sset - warm_up)) / warm_up
        return DAY_K - (DAY_K - WARM_K) * f
    return WARM_K


def boundaries(now):
    """Sunrises and sunsets of yesterday and today: an override ends at the next one."""
    today = now.date()
    out = []
    for d in (today - dt.timedelta(days=1), today):
        out.extend(sun_times(d))
    return out


def read_override(now):
    """True = forced warm, False = forced day, None = follow the schedule."""
    try:
        with open(OVERRIDE) as f:
            o = json.load(f)
        set_at = dt.datetime.fromisoformat(o["set"])
    except (OSError, ValueError, KeyError):
        return None
    if any(set_at < b <= now for b in boundaries(now)):
        try:
            os.remove(OVERRIDE)
        except OSError:
            pass
        return None
    return bool(o["warm"])


def effective_k(now):
    ovr = read_override(now)
    if ovr is None:
        return target_k(now)
    return WARM_K if ovr else DAY_K


def ensure_running():
    if subprocess.run(["pgrep", "-x", "hyprsunset"], capture_output=True).returncode != 0:
        subprocess.Popen(["hyprsunset", "-i"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)


def apply(now):
    k = round(effective_k(now))
    ensure_running()
    if k >= DAY_K - 50:
        req = ["hyprctl", "hyprsunset", "identity"]
    else:
        req = ["hyprctl", "hyprsunset", "temperature", str(round(k / 50) * 50)]
    subprocess.run(req, capture_output=True)
    return k


def notify(text):
    subprocess.run(["notify-send", "-a", "nightlight", "-u", "low", "-t", "1500",
                    "-h", "string:x-dunst-stack-tag:nightlight", "Night light", text],
                   capture_output=True)


def cmd_toggle():
    now = dt.datetime.now(TZ)
    warm_now = effective_k(now) < DAY_K - 50
    with open(OVERRIDE, "w") as f:
        json.dump({"warm": not warm_now, "set": now.isoformat()}, f)
    apply(now)
    notify("off" if warm_now else "on (%dK)" % WARM_K)


def cmd_daemon():
    with open(LOCK, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return          # already running
        while True:
            try:
                apply(dt.datetime.now(TZ))
            except Exception as e:      # keep going; the next pass retries
                print("nightlight:", e, file=sys.stderr)
            time.sleep(30)


def cmd_status(now):
    rise, sset = sun_times(now.date())
    ovr = read_override(now)
    print("now        %s" % now.strftime("%H:%M"))
    print("sunrise    %s" % rise.strftime("%H:%M"))
    print("sunset     %s" % sset.strftime("%H:%M"))
    print("schedule   %s K" % round(target_k(now)))
    print("override   %s" % ("none" if ovr is None else ("warm" if ovr else "day")))


def main(argv):
    args = argv[1:]
    cmd = args[0] if args else "status"
    if cmd == "daemon":
        cmd_daemon()
    elif cmd == "toggle":
        cmd_toggle()
    elif cmd == "status":
        now = dt.datetime.now(TZ)
        if "--at" in args:
            hh, mm = map(int, args[args.index("--at") + 1].split(":"))
            now = now.replace(hour=hh, minute=mm, second=0, microsecond=0)
        cmd_status(now)
    else:
        print("usage: nightlight.py daemon|toggle|status [--at HH:MM]", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
