import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import Quickshell.Wayland

// Lock screen (replaces hyprlock; hyprlock stays as the fallback).
//
//   the wallpaper, the clock in the sky above the mountain, the date spaced
//   below; the password as dots over a glowing horizon line (red after a
//   wrong one, "CAPS LOCK" in amber); the battery at the bottom.
//   Keys: type · Enter unlock · Escape / Ctrl+U clear · Backspace
//
// Lock:  scripts/lock.sh  (hypridle's lock_cmd; falls back to hyprlock if this
//        can't lock). Password check: PAM service "hyprlock" (includes login).
//
// Safety:
//  * A marker file in $XDG_RUNTIME_DIR says "locked". If Quickshell crashes
//    while locked, Hyprland stays locked; the restart loop brings Quickshell
//    back, it sees the marker and locks again. (If it can't: Ctrl+Alt+F3,
//    log in, `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`.)
//  * Config reloads are switched off while locked (Quickshell.watchFiles) and
//    `shell reload` is refused: a reload while locked is the risky moment.
//
//   qs ipc call lock lock      lock now
//   qs ipc call lock secure    true once the compositor confirmed the lock
Scope {
    id: root

    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/horizon-locked"

    property bool wanted: false          // lock requested
    readonly property bool locked: wanted
    property string pw: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool capsOn: false

    function lock() {
        if (wanted) return;
        pw = ""; failed = false; message = ""; busy = false;
        Quickshell.execDetached(["touch", marker]);
        Quickshell.watchFiles = false;
        wanted = true;
    }
    function finishUnlock() {
        wanted = false;
        pw = "";
        Quickshell.execDetached(["rm", "-f", marker]);
        Quickshell.watchFiles = true;
    }
    function submit() {
        if (busy || pw === "") return;
        busy = true; failed = false; message = "";
        pam.start();
    }

    // Locked when Quickshell (re)starts? Then lock again straight away.
    Process {
        command: ["test", "-e", root.marker]
        running: true
        onExited: code => { if (code === 0) root.lock() }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: { if (responseRequired) respond(root.pw) }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.finishUnlock();
            } else {
                root.failed = true;
                root.message = result === PamResult.MaxTries ? "too many tries" : "wrong password";
                root.pw = "";
            }
        }
        onError: err => {
            root.busy = false; root.failed = true;
            root.message = "authentication error"; root.pw = "";
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function secure(): bool { return sl.secure }
    }

    WlSessionLock {
        id: sl
        locked: root.wanted

        WlSessionLockSurface {
            id: surf
            color: Theme.ground

            readonly property real u: height / 1200

            FocusScope {
                id: scope
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: event => {
                    event.accepted = true;
                    if (root.busy) return;
                    const k = event.key;
                    const ctrl = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.submit(); return; }
                    if (k === Qt.Key_Escape || (ctrl && k === Qt.Key_U) || (ctrl && k === Qt.Key_Backspace)) {
                        root.pw = ""; root.failed = false; root.message = ""; return;
                    }
                    if (k === Qt.Key_Backspace) { root.pw = root.pw.slice(0, -1); root.failed = false; return; }
                    if (!ctrl && event.text.length === 1 && event.text >= " ") {
                        root.pw += event.text; root.failed = false; root.message = "";
                        // Wayland gives no Caps Lock state: infer it from letter case vs Shift
                        const ch = event.text;
                        if (ch.toUpperCase() !== ch.toLowerCase())
                            root.capsOn = (ch === ch.toUpperCase()) !== ((event.modifiers & Qt.ShiftModifier) !== 0);
                    }
                }

                Item {
                    id: content
                    anchors.fill: parent
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    Component.onCompleted: opacity = 1

                    Image {
                        anchors.fill: parent
                        source: Theme.wallpaper
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.round(surf.width / 2)
                        sourceSize.height: Math.round(surf.height / 2)
                    }

                    SystemClock { id: clock; precision: SystemClock.Minutes }

                    // the clock, in the sky
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(parent.height * 0.11)
                        text: Qt.formatTime(clock.date, "HH:mm")
                        color: Theme.fg
                        font.family: Theme.font
                        font.weight: Font.ExtraLight
                        font.pixelSize: Math.round(150 * surf.u)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(parent.height * 0.29)
                        text: Qt.formatDate(clock.date, "dddd d MMMM").toUpperCase()
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Math.round(14 * surf.u)
                        font.letterSpacing: 4 * surf.u
                    }

                    // the password, on the ground below the horizon
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(parent.height * 0.66)
                        spacing: Math.round(10 * surf.u)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Quickshell.env("USER")
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Math.round(13 * surf.u)
                            font.letterSpacing: 1
                        }

                        Item {
                            width: Math.round(340 * surf.u)
                            height: Math.round(40 * surf.u)
                            Text {
                                anchors.centerIn: parent
                                visible: root.pw === ""
                                text: root.busy ? "checking…" : "type to unlock"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Math.round(13 * surf.u)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: root.pw !== ""
                                text: "•".repeat(Math.min(root.pw.length, 24))
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Math.round(18 * surf.u)
                                font.letterSpacing: 6 * surf.u
                            }
                        }

                        // the horizon line: soft glow, brighter while typing, red on failure
                        Item {
                            id: hline
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(340 * surf.u)
                            height: 5
                            readonly property color tone: root.failed ? Theme.red : Theme.accent
                            opacity: root.failed || root.pw !== "" ? 1 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Rectangle {
                                anchors.fill: parent
                                radius: 2.5
                                opacity: 0.25
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: hline.tone }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: hline.tone }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }

                        Text {   // status line, fixed height so nothing jumps
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: Math.round(16 * surf.u)
                            text: root.failed ? root.message : root.capsOn ? "CAPS LOCK" : root.message
                            color: root.failed ? Theme.red : root.capsOn ? Theme.amber : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Math.round(11 * surf.u)
                            font.letterSpacing: 1.5
                        }
                    }

                    // battery, since the bar is hidden while locked
                    Text {
                        readonly property var b: UPower.displayDevice
                        visible: b !== null && b.isLaptopBattery
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(28 * surf.u)
                        textFormat: Text.StyledText
                        text: !b ? "" : (UPower.onBattery ? "BAT " : b.state === UPowerDeviceState.Charging ? "CHR " : "AC ")
                              + "<font color='" + Theme.muted + "'>" + Math.round(b.percentage > 1 ? b.percentage : b.percentage * 100) + "</font>"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Math.round(12 * surf.u)
                    }
                }
            }
        }
    }
}
