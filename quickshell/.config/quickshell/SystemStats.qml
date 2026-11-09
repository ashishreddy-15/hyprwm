pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU package temperature, memory in use and pending updates, shared by every
// bar's glance (BarSystemGlance.qml) so they're read once, not once per screen.
// Read only while at least one glance is showing (`watchers` > 0).
//   updates: `dnf check-update -C`, from the cache dnf-makecache.timer keeps
//            fresh (no sudo, no network); at most every 30 minutes.
Singleton {
    id: root

    property int watchers: 0           // glances currently showing
    property int temp: -1              // °C
    property real memGiB: -1
    property int updates: -1           // -1 = not checked yet
    property real _lastUpdateCheck: 0  // ms since epoch

    Process {
        id: readSys
        command: ["sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && { cat $z/temp; break; }; done; " +
            "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const t = Number(lines[0]);
                root.temp = isNaN(t) ? -1 : Math.round(t / 1000);
                const kb = name => Number((lines.find(l => l.startsWith(name)) || "x 0").split(/\s+/)[1]);
                const used = kb("MemTotal:") - kb("MemAvailable:");
                if (used > 0) root.memGiB = used / 1048576;
            }
        }
    }

    Process {
        id: readUpdates
        command: ["sh", "-c", "dnf check-update -C -q 2>/dev/null | grep -cE '^[^[:space:]]+\\.[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                root.updates = isNaN(n) ? 0 : n;
                root._lastUpdateCheck = Date.now();
            }
        }
    }

    function refresh() {
        if (!readSys.running) readSys.running = true;
        if (!readUpdates.running && Date.now() - _lastUpdateCheck > 30 * 60 * 1000) readUpdates.running = true;
    }
    onWatchersChanged: if (watchers > 0) refresh()
    Timer { interval: 10000; running: root.watchers > 0; repeat: true; onTriggered: root.refresh() }
}
