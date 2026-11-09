import QtQuick
import Quickshell
import Quickshell.Io

// Quiet system glance for an empty workspace:   cpu 56°   mem 5.4 GB   updates 13
//   cpu      package temperature (x86_pkg_temp); amber from 85°, red from 95°
//   mem      used memory (total − available)
//   updates  from `dnf check-update -C`: the cache dnf-makecache.timer keeps
//            fresh, so no sudo and no network. Click: kitty with `sudo dnf upgrade`.
// Temperature and memory every 10 s, updates at most every 30 min, and only
// while `active` (shown), so it costs nothing the rest of the time.
Item {
    id: glance

    property int fontSize: 13
    property bool active: false

    property int temp: -1              // °C
    property real memGiB: -1
    property int updates: -1           // -1 = not checked yet
    property real _lastUpdateCheck: 0  // ms since epoch

    implicitWidth: line.implicitWidth
    implicitHeight: fontSize * 1.4

    readonly property string memText: memGiB < 0 ? "–"
        : memGiB < 1 ? Math.round(memGiB * 1024) + " MB"
        : memGiB.toFixed(1) + " GB"
    readonly property color tempColor: temp >= 95 ? Theme.red : temp >= 85 ? Theme.amber : Theme.muted

    // temperature + memory
    Process {
        id: readSys
        command: ["sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && { cat $z/temp; break; }; done; " +
            "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const t = Number(lines[0]);
                glance.temp = isNaN(t) ? -1 : Math.round(t / 1000);
                const kb = name => Number((lines.find(l => l.startsWith(name)) || "x 0").split(/\s+/)[1]);
                const used = kb("MemTotal:") - kb("MemAvailable:");
                if (used > 0) glance.memGiB = used / 1048576;
            }
        }
    }

    // pending updates (cached metadata only)
    Process {
        id: readUpdates
        command: ["sh", "-c", "dnf check-update -C -q 2>/dev/null | grep -cE '^[^[:space:]]+\\.[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                glance.updates = isNaN(n) ? 0 : n;
                glance._lastUpdateCheck = Date.now();
            }
        }
    }

    function refresh() {
        if (!readSys.running) readSys.running = true;
        if (!readUpdates.running && Date.now() - _lastUpdateCheck > 30 * 60 * 1000) readUpdates.running = true;
    }
    Timer { interval: 10000; running: glance.active; repeat: true; triggeredOnStart: true; onTriggered: glance.refresh() }

    // One line at the bar's normal size, two tones like the window title
    // (labels dim, values grey); plain spacing instead of separators.
    Text {
        id: line
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.StyledText
        font.family: Theme.font
        font.pixelSize: glance.fontSize
        color: Theme.dim
        function v(c, s) { return "<font color='" + c + "'>" + s + "</font>" }
        readonly property string gap: "&nbsp;&nbsp;"   // three spaces read as separate pieces
        text: "cpu " + v(glance.tempColor, glance.temp < 0 ? "–" : glance.temp + "°")
            + gap + "mem " + v(Theme.muted, glance.memText)
            + gap + (glance.updates < 0 ? "updates " + v(Theme.muted, "–")
                   : glance.updates === 0 ? "up to date"
                   : "updates " + v(Theme.muted, glance.updates))
    }

    // click the updates part: a terminal with the upgrade ready to run
    MouseArea {
        anchors.fill: parent
        enabled: glance.updates > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: Quickshell.execDetached(["kitty", "--hold", "sh", "-c", "sudo dnf upgrade --refresh"])
    }
}
