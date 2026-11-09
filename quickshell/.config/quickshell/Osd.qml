import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// On-screen display above the bar, on the focused screen, for ~1.2 s:
//   VOL ━━━━━━──── 62   when the default output's volume or mute changes
//   BRT ━━━━━━──── 40   qs ipc call osd brightness <value> <label>  (brightness.sh)
//   short messages      Status.message(...) e.g. do not disturb on/off
Scope {
    id: root

    property string label: ""
    property int value: 0
    property bool muted: false
    property string text: ""        // message mode when non-empty
    property bool shown: false

    function showLevel(l, v, m) { text = ""; label = l; value = v; muted = m; shown = true; hideTimer.restart() }
    function showText(t) { text = t; shown = true; hideTimer.restart() }

    Timer { id: hideTimer; interval: 1200; onTriggered: root.shown = false }

    // Don't flash the OSD for the initial volume read at startup
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    Connections {
        target: root.audio
        function onVolumeChanged() { if (root.armed) root.showLevel("VOL", Math.round(root.audio.volume * 100), root.audio.muted) }
        function onMutedChanged()  { if (root.armed) root.showLevel(root.audio.muted ? "MUTE" : "VOL", Math.round(root.audio.volume * 100), root.audio.muted) }
    }

    Connections {
        target: Status
        function onLevel(l, v, m) { root.showLevel(l, v, m) }
        function onMessage(t) { root.showText(t) }
    }

    IpcHandler {
        target: "osd"
        function brightness(value: int, label: string): void { root.showLevel("BRT", value, false) }
        function message(text: string): void { root.showText(text) }
    }

    PanelWindow {
        id: win

        screen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens) if (s.name === name) return s;
            return Quickshell.screens[0];
        }
        readonly property bool laptop: screen && screen.name.startsWith("eDP")
        readonly property int fontSize: laptop ? 14 : 12

        visible: box.opacity > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-osd"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        // just above the bar island, with 10 px of room below the box to rise through
        margins.bottom: (laptop ? 32 : 28) + 4 + 2
        implicitWidth: Math.round(fontSize * 24)
        implicitHeight: Math.round(fontSize * 3) + 10
        mask: Region {}   // display only: clicks go through
        color: "transparent"

        Rectangle {
            id: box
            width: parent.width
            height: parent.height - 10
            radius: 8
            color: Theme.alpha(Theme.surface, Theme.panelAlpha)
            border.color: Theme.border
            border.width: 1
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuint } }

            Spring { id: lift; preset: Theme.springs.rise; to: root.shown ? 0 : 10 }
            transform: Translate { y: lift.value }

            // message
            Text {
                anchors.centerIn: parent
                visible: root.text !== ""
                text: root.text
                font.family: Theme.font
                font.pixelSize: win.fontSize
                font.letterSpacing: 1.5
                color: Theme.fg
            }

            // level
            Row {
                anchors.centerIn: parent
                visible: root.text === ""
                spacing: Math.round(win.fontSize * 0.9)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: win.fontSize * 3
                    text: root.label
                    font.family: Theme.font
                    font.pixelSize: win.fontSize * 0.86
                    color: Theme.muted
                }

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: win.fontSize * 14
                    height: 2
                    radius: 1
                    color: Theme.border
                    opacity: root.muted ? 0.5 : 1

                    // the fill reveals a gradient as wide as the track: the
                    // colour says the level (deep sky low, bright accent high)
                    Item {
                        id: fill
                        height: parent.height
                        Spring { id: fillW; preset: Theme.springs.settle; to: Math.max(0, Math.min(1, root.value / 100)) * track.width }
                        width: fillW.value
                        clip: true
                        Rectangle {
                            width: track.width
                            height: parent.height
                            radius: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.sky }
                                GradientStop { position: 1.0; color: Theme.accent }
                            }
                        }
                    }

                    // knob at the end of the fill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: fill.width - width / 2
                        width: 6
                        height: 6
                        radius: 3
                        color: root.muted ? Theme.muted : Theme.fg
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: win.fontSize * 2
                    horizontalAlignment: Text.AlignRight
                    text: root.value
                    font.family: Theme.font
                    font.pixelSize: win.fontSize
                    color: root.muted ? Theme.muted : Theme.fg
                }
            }
        }
    }
}
