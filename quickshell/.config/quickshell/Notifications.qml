import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Notification server for the Hyprland session (replaces dunst there).
// Popups appear top-right on the focused screen, newest on top, at most 5.
// Everything stays in history until dismissed or cleared.
//
//   qs ipc call notifications history   re-show the latest closed one (Super+`)
//   qs ipc call notifications clear     dismiss everything             (Super+Shift+`)
//   qs ipc call notifications dnd       do not disturb on/off          (Super+Shift+N)
//
// Do not disturb holds back popups except critical ones; the bar shows DND.
// Same stack tag (x-dunst-stack-tag / x-canonical-private-synchronous)
// replaces the older notification, so brightness/recording don't pile up.
Scope {
    id: root

    property var popups: []

    function tagOf(n) {
        const h = n.hints || {};
        return h["x-dunst-stack-tag"] || h["x-canonical-private-synchronous"] || "";
    }
    function show(n) { popups = [n].concat(popups.filter(p => p !== n)).slice(0, 5) }
    function hide(n) { popups = popups.filter(p => p !== n) }
    // re-show the latest notification that isn't on screen
    function historyPop() {
        const list = Array.from(server.trackedNotifications.values).filter(n => popups.indexOf(n) < 0);
        if (list.length > 0) show(list[list.length - 1]);
    }
    function clearAll() {
        for (const n of Array.from(server.trackedNotifications.values)) n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            const tag = root.tagOf(n);
            if (tag !== "") {
                for (const old of Array.from(server.trackedNotifications.values))
                    if (old !== n && root.tagOf(old) === tag) old.dismiss();
            }
            if (Status.dnd && n.urgency !== NotificationUrgency.Critical) return;
            root.show(n);
        }
    }

    IpcHandler {
        target: "notifications"

        function history(): void { root.historyPop() }
        function clear(): void { root.clearAll() }
        function dnd(): void { Status.toggleDnd() }
    }

    PanelWindow {
        id: win

        screen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens) if (s.name === name) return s;
            return Quickshell.screens[0];
        }
        visible: root.popups.length > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-notifications"
        exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        anchors.right: true
        margins.top: 6
        margins.right: 6
        implicitWidth: 400
        implicitHeight: Math.max(1, stack.implicitHeight + 20)
        color: "transparent"

        Column {
            id: stack
            x: 10
            y: 10
            width: win.width - 20
            spacing: 8

            move: Transition { NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Easing.OutQuint } }

            Repeater {
                model: root.popups
                delegate: NotificationCard {
                    onTimedOut: root.hide(notif)
                    Connections {
                        target: notif
                        function onClosed() { root.hide(notif) }
                    }
                }
            }
        }
    }
}
