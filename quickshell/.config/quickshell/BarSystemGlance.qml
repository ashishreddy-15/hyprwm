import QtQuick
import Quickshell

// Quiet system glance, shown where the bar has no window title to show (an
// empty workspace, or a screen that doesn't have focus):
//   cpu 56°   mem 5.2 GB   updates 13
//   cpu      package temperature; amber from 85°, red from 95°
//   mem      memory in use
//   updates  pending updates; click: kitty with `sudo dnf upgrade`
// The values come from SystemStats (shared, read only while a glance shows).
Item {
    id: glance

    property int fontSize: 13
    property bool active: false

    readonly property int temp: SystemStats.temp
    readonly property real memGiB: SystemStats.memGiB
    readonly property int updates: SystemStats.updates

    implicitWidth: line.implicitWidth
    implicitHeight: fontSize * 1.4

    readonly property string memText: memGiB < 0 ? "–"
        : memGiB < 1 ? Math.round(memGiB * 1024) + " MB"
        : memGiB.toFixed(1) + " GB"
    readonly property color tempColor: temp >= 95 ? Theme.red : temp >= 85 ? Theme.amber : Theme.muted

    // tell SystemStats while this glance is showing, so it only reads then
    property bool _counted: false
    function sync() {
        if (active && !_counted) { SystemStats.watchers += 1; _counted = true; }
        else if (!active && _counted) { SystemStats.watchers -= 1; _counted = false; }
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (_counted) SystemStats.watchers -= 1

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
