import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets

// Polkit agent (replaces hyprpolkitagent; it stays as the fallback).
//
//   The password prompt for system actions (pkexec, installing software,
//   power settings…), in the lock screen's style: a card over the dimmed,
//   blurred desktop on the focused screen. The app's icon in grey, polkit's
//   own message, the user to authenticate as (click to switch when there are
//   several), the password as dots over the horizon line, red after a wrong
//   one, CAPS LOCK in amber. "details" shows the polkit action id.
//   Keys: type · Enter authenticate · Escape cancel · Ctrl+U clear
//
// The password goes straight to polkit (which checks it through PAM);
// nothing is kept. Only one agent can be registered per session: if
// Quickshell can't register (another agent holds the session), hyprpolkitagent
// is started instead so prompts always work.
//
//   qs ipc call polkit cancel     cancel the open request
//   qs ipc call polkit status     "registered" / "not registered"
Scope {
    id: root

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow
    readonly property bool open: flow !== null && !flow.isCompleted
    property string pw: ""
    property bool failed: false
    property bool capsOn: false
    property bool details: false

    function submit() {
        if (!flow || !flow.isResponseRequired) return;
        flow.submit(pw);
        pw = "";
    }
    function cancel() { if (flow) flow.cancelAuthenticationRequest() }

    onFlowChanged: { pw = ""; failed = false; details = false; if (flow) { rise.from(20); Qt.callLater(() => keys.forceActiveFocus()) } }
    Connections {
        target: root.flow
        function onAuthenticationFailed() { root.failed = true; root.pw = ""; shake.restart() }
        function onIsResponseRequiredChanged() { if (root.flow && root.flow.isResponseRequired) Qt.callLater(() => keys.forceActiveFocus()) }
    }

    // fallback: no agent of ours a few seconds after start → hyprpolkitagent
    Timer {
        running: true
        interval: 4000
        onTriggered: if (!agent.isRegistered) {
            console.warn("polkit: Quickshell agent not registered; starting hyprpolkitagent");
            Quickshell.execDetached(["systemctl", "--user", "start", "hyprpolkitagent"]);
        }
    }

    IpcHandler {
        target: "polkit"
        function cancel(): void { root.cancel() }
        function status(): string { return agent.isRegistered ? "registered" : "not registered" }
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

        visible: root.open || card.opacity > 0.01
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // the desktop stays visible, dimmed (Hyprland blurs it: rules.lua);
        // clicks on it do nothing until the request is answered
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.55)
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            id: card
            readonly property real u: win.fontSize
            width: Math.round(u * 32)
            implicitHeight: col.implicitHeight + Math.round(u * 4)
            height: implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((parent.height - height) * 0.42)
            radius: 10
            color: Theme.alpha(Theme.surface, Theme.popupAlpha)
            border.color: Theme.border
            border.width: 1

            Spring { id: rise; preset: Theme.springs.rise; to: 0 }
            opacity: root.open ? Math.min(1, 2 * (1 - rise.value / 20)) : 0
            Behavior on opacity { enabled: !root.open; NumberAnimation { duration: 120 } }
            transform: Translate { id: nudge; y: rise.value }

            // a wrong password: a small sideways shake, settling fast
            SequentialAnimation {
                id: shake
                NumberAnimation { target: nudge; property: "x"; to: -8; duration: 45; easing.type: Easing.OutQuad }
                NumberAnimation { target: nudge; property: "x"; to: 6; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: nudge; property: "x"; to: -3; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
            }

            Item {
                id: keys
                focus: root.open
                Keys.onPressed: event => {
                    event.accepted = true;
                    const k = event.key;
                    const ctrl = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
                    if (k === Qt.Key_Escape) { root.cancel(); return; }
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.submit(); return; }
                    if (ctrl && (k === Qt.Key_U || k === Qt.Key_Backspace)) { root.pw = ""; return; }
                    if (k === Qt.Key_Backspace) { root.pw = root.pw.slice(0, -1); return; }
                    if (!ctrl && event.text.length === 1 && event.text >= " ") {
                        root.pw += event.text; root.failed = false;
                        // Wayland gives no Caps Lock state: infer it from letter case vs Shift
                        const ch = event.text;
                        if (ch.toUpperCase() !== ch.toLowerCase())
                            root.capsOn = (ch === ch.toUpperCase()) !== ((event.modifiers & Qt.ShiftModifier) !== 0);
                    }
                }
            }

            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(card.u * 2)
                width: parent.width - Math.round(card.u * 4)
                spacing: Math.round(card.u * 0.9)

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property string name: root.flow && root.flow.iconName !== "" ? root.flow.iconName : "dialog-password"
                    source: Quickshell.iconPath(name, "dialog-password")
                    implicitSize: Math.round(card.u * 2.6)
                    layer.enabled: true
                    layer.effect: MultiEffect { saturation: -1 }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "AUTHENTICATION"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Math.round(card.u * 0.8)
                    font.letterSpacing: 3
                }

                // polkit's message; pkexec puts the whole command line in it, so
                // it's capped at 5 lines (the full text is under "details")
                Text {
                    id: message
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    text: root.flow ? root.flow.message : ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: card.u
                    lineHeight: 1.25
                }

                Item { width: 1; height: Math.round(card.u * 0.3) }

                // who to authenticate as; several admins → click to switch
                Text {
                    id: who
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var ids: root.flow ? root.flow.identities : []
                    readonly property var cur: root.flow ? root.flow.selectedIdentity : null
                    function label(i) { return i ? (i.displayName || i.name || "") : "" }
                    text: (label(cur) || Quickshell.env("USER")) + (ids.length > 1 ? "  ⌄" : "")
                    color: whoMouse.containsMouse && ids.length > 1 ? Theme.muted : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Math.round(card.u * 0.9)
                    MouseArea {
                        id: whoMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        enabled: who.ids.length > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const i = who.ids.indexOf(who.cur);
                            root.flow.selectedIdentity = who.ids[(i + 1) % who.ids.length];
                            root.pw = ""; root.failed = false;
                        }
                    }
                }

                // the password over the horizon line
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(card.u * 22)
                    height: Math.round(card.u * 2.6)
                    Text {
                        anchors.centerIn: parent
                        visible: root.pw === ""
                        text: root.flow && !root.flow.isResponseRequired ? "checking…" : "password"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: card.u
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.pw !== ""
                        text: root.flow && root.flow.responseVisible ? root.pw : "•".repeat(Math.min(root.pw.length, 24))
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Math.round(card.u * 1.25)
                        font.letterSpacing: root.flow && root.flow.responseVisible ? 0 : 5
                    }
                }
                Item {
                    id: hline
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(card.u * 22)
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
                    width: parent.width
                    height: Math.round(card.u * 1.3)
                    horizontalAlignment: Text.AlignHCenter
                    readonly property string extra: root.flow ? root.flow.supplementaryMessage : ""
                    readonly property bool extraErr: root.flow ? root.flow.supplementaryIsError : false
                    text: root.failed ? "wrong password"
                        : root.capsOn && root.pw !== "" ? "CAPS LOCK"
                        : extra
                    color: root.failed || extraErr ? Theme.red : root.capsOn ? Theme.amber : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Math.round(card.u * 0.8)
                    font.letterSpacing: 1.5
                    elide: Text.ElideRight
                }

                // details · cancel · authenticate
                Item {
                    width: parent.width
                    height: Math.round(card.u * 1.6)
                    TextLink {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.details ? "hide details" : "details"
                        tone: Theme.dim
                        size: Math.round(card.u * 0.9)
                        onClicked: root.details = !root.details
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(card.u * 1.4)
                        TextLink { text: "cancel"; tone: Theme.muted; size: Math.round(card.u * 0.9); onClicked: root.cancel() }
                        TextLink { text: "authenticate"; tone: Theme.fg; size: Math.round(card.u * 0.9); onClicked: root.submit() }
                    }
                }

                // details: the action id, and the full message when it was cut
                // short; scrolls past ~10 lines so the card stays on screen
                Flickable {
                    visible: root.details
                    width: parent.width
                    height: Math.min(detailText.implicitHeight, Math.round(card.u * 13))
                    contentHeight: detailText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: detailText
                        width: parent.width
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        text: !root.flow ? "" : root.flow.actionId
                            + (message.truncated ? "\n\n" + root.flow.message : "")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Math.round(card.u * 0.8)
                        lineHeight: 1.2
                    }
                }
            }
        }
    }

    component TextLink: Text {
        property color tone: Theme.muted
        property int size: 13
        signal clicked()
        color: m.containsMouse ? Theme.fg : tone
        font.family: Theme.font
        font.pixelSize: size
        MouseArea {
            id: m
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
