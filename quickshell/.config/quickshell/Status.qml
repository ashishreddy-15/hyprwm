pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Session state the bar shows, plus the OSD request channel.
// Modes are polled every 2 s (cheap: one pgrep + one file test).
Singleton {
    id: root

    property bool recording: false   // wf-recorder running (Shift+Print)
    property bool keepAwake: false   // hypridle without timeouts (keep-awake.sh)
    property bool nightLight: false  // hyprsunset running (Super+N)
    property bool dnd: false         // notifications paused (Super+Shift+N)
    property bool barShown: true     // Super+B hides / shows the bar on every screen

    // OSD requests: Osd.qml listens to these
    signal level(string label, int value, bool muted)
    signal message(string text)

    function toggleKeepAwake() {
        Quickshell.execDetached([Theme.scripts + "keep-awake.sh", "toggle"]);
        repoll.restart();
    }

    function toggleDnd() {
        dnd = !dnd;
        message(dnd ? "DO NOT DISTURB  ON" : "DO NOT DISTURB  OFF");
    }

    function refresh() { if (!poll.running) poll.running = true }

    Process {
        id: poll
        command: ["sh", "-c",
            "pgrep -xu \"$USER\" wf-recorder >/dev/null && echo rec;" +
            "[ -e \"$XDG_RUNTIME_DIR/hypr-keep-awake\" ] && echo awake;" +
            "pgrep -xu \"$USER\" hyprsunset >/dev/null && echo night; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text;
                root.recording = t.indexOf("rec") >= 0;
                root.keepAwake = t.indexOf("awake") >= 0;
                root.nightLight = t.indexOf("night") >= 0;
            }
        }
    }

    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: repoll; interval: 350; onTriggered: root.refresh() }
}
