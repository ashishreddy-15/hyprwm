import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// Glow island: one centred island at the bottom of every screen.
//   left:   this screen's workspaces · the focused window, or a system glance
//   centre: date and time (click: calendar)
//   right:  modes (REC, AWAKE, DND, PERF in amber; SAVER grey; only while on) · VOL · BAT (click: power panel) · tray
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
        // Super+B: the island slides down out of view and its space is given
        // back to windows; clicks pass through while hidden
        exclusiveZone: Status.barShown ? islandHeight : 0
        mask: Region { item: hitbox }
        color: "transparent"
        Spring { id: hideY; preset: Theme.springs.rise; to: Status.barShown ? 0 : bar.islandHeight + bar.glowRoom + 6 }
        readonly property real shownness: 1 - hideY.value / (islandHeight + glowRoom + 6)

        // input region: tracks real geometry (collapsed to nothing while hidden),
        // since swapping the Region's item to null and back left clicks dead
        Item {
            id: hitbox
            x: 0
            y: bar.glowRoom
            width: Status.barShown ? bar.width : 0
            height: Status.barShown ? bar.height - bar.glowRoom : 0
        }

        Calendar { id: calendar; bar: bar }
        PowerPanel { id: powerPanel; bar: bar }   // click the battery meter

        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var battery: UPower.displayDevice

        Rectangle {
            id: island
            transform: Translate { y: hideY.value }
            opacity: bar.shownness
            anchors.fill: parent
            anchors.topMargin: bar.glowRoom
            radius: 8
            color: Theme.alpha(Theme.surface, Theme.panelAlpha)
            border.color: Theme.border
            border.width: 1

            readonly property int pad: Math.round(bar.fontSize * 0.8)

            // ── Left: workspaces + context ──
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

                // the focused window, or a system glance (BarContext.qml);
                // capped, and always a clear gap before the clock
                BarContext {
                    anchors.verticalCenter: parent.verticalCenter
                    monitor: bar.monitor
                    fontSize: bar.fontSize
                    maxWidth: Math.max(0, Math.min(bar.fontSize * 26,
                        clock.x - left.x - workspaces.width - left.spacing - bar.fontSize * 3))
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
                // power profile: Balanced is normal and shows nothing (as in the Sway bar)
                ModeLabel { size: bar.fontSize; text: "PERF";  shown: PowerProfiles.profile === PowerProfile.Performance; onClicked: powerPanel.open = !powerPanel.open }
                ModeLabel { size: bar.fontSize; text: "SAVER"; shown: PowerProfiles.profile === PowerProfile.PowerSaver; tone: Theme.muted; onClicked: powerPanel.open = !powerPanel.open }

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
                    id: batteryMeter
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.battery !== null && bar.battery.isLaptopBattery
                    // charging: soft static glow; plug in / unplug / full: one sweep of light
                    readonly property bool charging: bar.battery !== null && bar.battery.state === UPowerDeviceState.Charging
                    readonly property bool full: bar.battery !== null && bar.battery.state === UPowerDeviceState.FullyCharged
                    lit: charging
                    onFullChanged: if (full) sweep(false)
                    Connections {
                        target: UPower
                        function onOnBatteryChanged() { batteryMeter.sweep(UPower.onBattery) }
                    }
                    readonly property real pct: !bar.battery ? 0
                        : (bar.battery.percentage > 1 ? bar.battery.percentage / 100 : bar.battery.percentage)
                    readonly property int whole: Math.round(pct * 100)
                    fontSize: bar.fontSize
                    // BAT on battery, CHR charging, AC plugged in but holding (e.g. at a charge limit)
                    label: UPower.onBattery ? "BAT" : bar.battery && bar.battery.state === UPowerDeviceState.Charging ? "CHR" : "AC"
                    onClicked: powerPanel.open = !powerPanel.open   // power profile + keep awake
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
            transform: Translate { y: hideY.value }
            x: island.x + island.radius
            width: island.width - 2 * island.radius
            y: bar.glowRoom - 2
            height: 5
            clip: true
            opacity: (bar.monitor && bar.monitor.focused ? 1 : 0.4) * bar.shownness
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        Item {
            id: glow
            readonly property real center: workspaces.activeCenter < 0 ? -1
                : island.x + left.x + workspaces.x + workspaces.activeCenter - glowClip.x
            readonly property real span: bar.fontSize * 11

            visible: center >= 0
            // drifts after the underline, like light catching up
            Spring { id: glowX; preset: Theme.springs.drift; to: glow.center - glow.span / 2 }
            x: glowX.value
            y: 2
            width: span
            height: 1


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
        property color tone: Theme.amber
        signal clicked()
        visible: shown
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: Theme.font
        font.pixelSize: size
        color: tone
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
