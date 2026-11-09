import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ambient screen: after a couple of minutes without input, every screen fades
// to the wallpaper with the clock large in the sky, as on the lock screen.
// Any key or mouse movement brings the desktop back. The lock screen still
// comes at 5 minutes (hypridle), and this stays off while keep-awake is on.
//
//   qs ipc call ambient reveal | conceal     (testing; "show" is reserved by qs)
Scope {
    id: root

    readonly property int idleSeconds: 120
    property bool forced: false          // set by the IPC (testing)
    property bool idleShown: idle.isIdle && !Status.keepAwake && !forced
    readonly property bool shown: forced || idleShown

    // Quickshell reports input from anywhere (windows, the overlay, the pointer)
    IdleMonitor {
        id: idle
        enabled: true
        timeout: root.idleSeconds
        respectInhibitors: true          // fullscreen video and similar still count as "in use"
    }

    IpcHandler {
        target: "ambient"
        function reveal(): void { root.forced = true }
        function conceal(): void { root.forced = false }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "horizon-ambient"
            // takes the keyboard while shown, so the key that wakes the screen is
            // not typed into a window behind it
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            // transparent: while hidden, nothing may be painted over the desktop
            color: "transparent"
            // clicks pass through while hidden
            mask: Region { item: root.shown ? full : null }

            readonly property real u: height / 1200

            Item {
                id: full
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.shown ? 1 : 0
                // a slow fade in, a quick one out
                Behavior on opacity { NumberAnimation { duration: root.shown ? 1400 : 220; easing.type: Easing.OutCubic } }

                Rectangle { anchors.fill: parent; color: Theme.ground }   // shown while the photo loads

                Image {
                    anchors.fill: parent
                    source: Theme.wallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: Math.round(win.width / 2)
                    sourceSize.height: Math.round(win.height / 2)
                }

                // the clock, in the sky above the mountain (same place as the lock screen)
                SystemClock { id: clock; precision: SystemClock.Minutes }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.11)
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.fg
                    opacity: 0.85
                    font.family: Theme.font
                    font.weight: Font.ExtraLight
                    font.pixelSize: Math.round(150 * win.u)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.29)
                    text: Qt.formatDate(clock.date, "dddd d MMMM").toUpperCase()
                    color: Theme.muted
                    opacity: 0.85
                    font.family: Theme.font
                    font.pixelSize: Math.round(14 * win.u)
                    font.letterSpacing: 4 * win.u
                }
            }
        }
    }
}
