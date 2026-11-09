import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// Glow island: one centred island at the bottom of every screen.
//   left:   this screen's workspaces · media (only while playing)
//   centre: date and time (click: calendar)
//   right:  modes (REC, AWAKE, DND, in amber, only while on) · VOL · BAT · tray
// A soft glow on the island's top edge sits above the active workspace;
// it dims on the screen that doesn't have focus.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData
        screen: modelData

        // Laptop panel (~160 ppi) gets larger text than the 27" (~109 ppi), as in Sway
        readonly property bool laptop: modelData.name.startsWith("eDP")
        readonly property int fontSize: laptop ? 14 : 12
        readonly property int islandHeight: laptop ? 32 : 28
        readonly property int glowRoom: 3
        readonly property var monitor: Hyprland.monitorFor(modelData)

        WlrLayershell.namespace: "horizon-bar"
        WlrLayershell.layer: WlrLayer.Top
        anchors.bottom: true
        margins.bottom: 4
        implicitWidth: Math.min(Math.round(modelData.width * 0.5), 1040)
        implicitHeight: islandHeight + glowRoom
        exclusiveZone: islandHeight
        color: "transparent"

        Calendar { id: calendar; bar: bar }

        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var battery: UPower.displayDevice

        Rectangle {
            id: island
            anchors.fill: parent
            anchors.topMargin: bar.glowRoom
            radius: 8
            color: Theme.alpha(Theme.surface, Theme.panelAlpha)
            border.color: Theme.border
            border.width: 1

            readonly property int pad: Math.round(bar.fontSize * 0.8)

            // ── Left: workspaces + media ──
            Row {
                id: left
                anchors.left: parent.left
                anchors.leftMargin: island.pad - 4
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: bar.fontSize

                BarWorkspaces {
                    id: workspaces
                    monitor: bar.monitor
                    fontSize: bar.fontSize
                    height: parent.height
                }

                BarMedia {
                    anchors.verticalCenter: parent.verticalCenter
                    fontSize: bar.fontSize
                    // room up to the clock, minus a gap
                    width: Math.max(0, Math.min(implicitWidth,
                        clock.x - left.x - workspaces.width - left.spacing - bar.fontSize * 1.5))
                }
            }

            // ── Centre: clock ──
            SystemClock { id: time; precision: SystemClock.Minutes }

            Row {
                id: clock
                anchors.centerIn: parent
                spacing: Math.round(bar.fontSize * 0.7)
                Text {
                    text: Qt.formatDateTime(time.date, "ddd dd")
                    font.family: Theme.font
                    font.pixelSize: bar.fontSize
                    color: Theme.muted
                }
                Text {
                    text: Qt.formatDateTime(time.date, "HH:mm")
                    font.family: Theme.font
                    font.pixelSize: bar.fontSize
                    color: Theme.fg
                }
            }

            // click the clock: month calendar (Calendar.qml)
            MouseArea {
                anchors.horizontalCenter: clock.horizontalCenter
                width: clock.width + bar.fontSize
                height: island.height
                cursorShape: Qt.PointingHandCursor
                onClicked: calendar.open = !calendar.open
            }

            // ── Right: modes, meters, tray ──
            Row {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: island.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(bar.fontSize * 1.1)

                ModeLabel { size: bar.fontSize; text: "REC";   shown: Status.recording }
                ModeLabel { size: bar.fontSize; text: "AWAKE"; shown: Status.keepAwake; onClicked: Status.toggleKeepAwake() }
                ModeLabel { size: bar.fontSize; text: "DND";   shown: Status.dnd;       onClicked: Status.toggleDnd() }

                BarMeter {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.sink !== null && bar.sink.audio !== null
                    readonly property bool muted: bar.sink && bar.sink.audio ? bar.sink.audio.muted : false
                    readonly property real vol: bar.sink && bar.sink.audio ? bar.sink.audio.volume : 0
                    fontSize: bar.fontSize
                    label: muted ? "MUTE" : "VOL"
                    fraction: vol
                    value: Math.round(vol * 100)
                    dimmed: muted
                    onClicked: bar.sink.audio.muted = !bar.sink.audio.muted
                    onScrolled: steps => bar.sink.audio.volume = Math.max(0, Math.min(1, vol + steps * 0.05))
                }

                BarMeter {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.battery !== null && bar.battery.isLaptopBattery
                    readonly property real pct: !bar.battery ? 0
                        : (bar.battery.percentage > 1 ? bar.battery.percentage / 100 : bar.battery.percentage)
                    readonly property int whole: Math.round(pct * 100)
                    fontSize: bar.fontSize
                    label: UPower.onBattery ? "BAT" : "AC"
                    fraction: pct
                    value: whole
                    // same thresholds as the Sway bar: warning 25, critical 15 (on battery only)
                    tone: !UPower.onBattery ? "transparent"
                        : whole <= 15 ? Theme.red
                        : whole <= 25 ? Theme.amber : "transparent"
                }

                BarTray {
                    anchors.verticalCenter: parent.verticalCenter
                    barWindow: bar
                    fontSize: bar.fontSize
                }
            }
        }

        // ── Glow on the top edge, above the active workspace ──
        // Clipped to the island's straight top edge (between the rounded corners),
        // so the glow stays centred over workspace 1 without spilling past the corner.
        Item {
            id: glowClip
            x: island.x + island.radius
            width: island.width - 2 * island.radius
            y: bar.glowRoom - 2
            height: 5
            clip: true
            opacity: bar.monitor && bar.monitor.focused ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        Item {
            id: glow
            readonly property real center: workspaces.activeCenter < 0 ? -1
                : island.x + left.x + workspaces.x + workspaces.activeCenter - glowClip.x
            readonly property real span: bar.fontSize * 11

            visible: center >= 0
            x: center - span / 2
            y: 2
            width: span
            height: 1

            Behavior on x { NumberAnimation { duration: Theme.normal + 80; easing.type: Easing.OutQuint } }

            // soft halo
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                opacity: 0.22
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                    GradientStop { position: 0.5; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                }
            }
            // core line
            Rectangle {
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                    GradientStop { position: 0.5; color: Theme.alpha(Theme.accent, 0.95) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                }
            }
        }
        }
    }

    component ModeLabel: Text {
        property bool shown: false
        property int size: 13
        signal clicked()
        visible: shown
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: Theme.font
        font.pixelSize: size
        color: Theme.amber
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
