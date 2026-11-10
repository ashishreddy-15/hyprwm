import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Power menu (Super+X), rising out of the bar like the launcher.
// Lock, Suspend and Restart shell (Quickshell, e.g. a meter stuck) run
// straight away: nothing is lost. Log out, Reboot and
// Shut down close every app, so the first Enter only arms them (the row turns
// amber and asks); a second Enter confirms. Moving or Escape cancels.
// Keys: Up/Down or J/K, Enter, or the letter shown on each row.
//
//   qs ipc call power toggle
Scope {
    id: root

    property bool open: false
    property int selected: 0
    property int armed: -1

    readonly property var actions: [
        { key: "l", label: "Lock",      confirm: false, run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { key: "s", label: "Suspend",   confirm: false, run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        // restarts this shell too, so the script runs detached (Super+Ctrl+R does the same)
        { key: "q", label: "Restart shell", confirm: false, run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/qs-restart.sh"]) },
        { key: "e", label: "Log out",   confirm: true,  run: () => Hyprland.dispatch("hl.dsp.exit()") },
        { key: "r", label: "Reboot",    confirm: true,  run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { key: "p", label: "Shut down", confirm: true,  run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
    ]

    function show() { selected = 0; armed = -1; open = true; rise.from(20); Qt.callLater(() => keys.forceActiveFocus()) }
    function hide() { open = false; armed = -1 }
    function toggle() { if (open) hide(); else show() }

    function pick(i) {
        const a = actions[i];
        if (!a) return;
        selected = i;
        if (a.confirm && armed !== i) { armed = i; return; }
        hide();
        a.run();
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
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
        readonly property int rowHeight: Math.round(fontSize * 2.6)

        // Always mapped (invisible and click-through while closed), so opening
        // starts on the next frame instead of waiting for a new surface.
        visible: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-power"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        // 20 px of transparent room under the panel to rise through (the window
        // clips anything drawn outside it); clicks there pass through to the bar
        margins.bottom: (laptop ? 32 : 28) + 4 - 10   // panel rests 10 px above the bar island
        implicitWidth: Math.round(fontSize * 24)
        implicitHeight: panel.implicitHeight + 20
        mask: Region { item: root.open ? panel : null }
        color: "transparent"

        // Click outside closes. Armed a moment after opening: the window stays
        // mapped, and a grab started before the input mask is applied gets
        // cleared straight away (which would close the panel on open).
        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: false
            onCleared: if (root.open) root.hide()
        }
        Timer { id: armGrab; interval: 60; onTriggered: grab.active = root.open }
        Connections {
            target: root
            function onOpenChanged() { if (root.open) armGrab.restart(); else grab.active = false }
        }

        Rectangle {
            id: panel
            width: parent.width
            implicitHeight: col.implicitHeight + 16
            radius: 10
            color: Theme.alpha(Theme.surface, Theme.popupAlpha)
            border.color: Theme.border
            border.width: 1

            // rises out of the bar on a spring, fading in over the first part of the way
            Spring { id: rise; preset: Theme.springs.rise; to: 0 }
            transform: Translate { y: rise.value }
            // opacity leads the motion: fully visible by half-way, so the first
            // frames (when a spring from rest has barely moved) aren't blank
            opacity: root.open ? Math.min(1, 2 * (1 - rise.value / 20)) : (warmedUp ? 0 : 0.01)
            // Drawn once at 1% (invisible) right after startup, so glyphs, icons and
            // effects are ready; a first open paid ~70 ms for that in the recording.
            property bool warmedUp: false
            Timer { running: true; interval: 1000; onTriggered: panel.warmedUp = true }
            // closing: a quick fade, no movement
            Behavior on opacity { enabled: !root.open; NumberAnimation { duration: 90 } }

            Item {
                id: keys
                focus: root.open
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Escape) { root.hide(); }
                    else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) { root.selected = Math.min(root.actions.length - 1, root.selected + 1); root.armed = -1; }
                    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) { root.selected = Math.max(0, root.selected - 1); root.armed = -1; }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.pick(root.selected); }
                    else {
                        const i = root.actions.findIndex(a => a.key === event.text.toLowerCase());
                        if (i >= 0) root.pick(i); else return;
                    }
                    event.accepted = true;
                }
            }

            Column {
                id: col
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 2

                Repeater {
                    model: root.actions

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === root.selected
                        readonly property bool isArmed: index === root.armed
                        width: col.width
                        height: win.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: row.isSelected ? Theme.raised : mouse.containsMouse ? Theme.hover : "transparent"
                        }
                        Rectangle {
                            visible: row.isSelected
                            x: 10
                            width: Math.min(parent.width * 0.4, 120)
                            anchors.bottom: parent.bottom
                            height: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                                GradientStop { position: 0.5; color: row.isArmed ? Theme.amber : Theme.accent }
                                GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.isArmed ? row.modelData.label + "?" : row.modelData.label
                            font.family: Theme.font
                            font.pixelSize: win.fontSize
                            color: row.isArmed ? Theme.amber : row.isSelected ? Theme.fg : Theme.muted
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.isArmed ? "↵ again to confirm" : row.modelData.key
                            font.family: Theme.font
                            font.pixelSize: win.fontSize * 0.85
                            color: row.isArmed ? Theme.amber : Theme.dim
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(row.index)
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.armed >= 0
                    leftPadding: 12
                    topPadding: 6
                    bottomPadding: 2
                    text: "Open apps will close without saving."
                    font.family: Theme.font
                    font.pixelSize: win.fontSize * 0.8
                    color: Theme.dim
                }
            }
        }
    }
}
