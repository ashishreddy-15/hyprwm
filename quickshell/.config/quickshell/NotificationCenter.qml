import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Notification center (Super+`): everything not yet dismissed, grouped by
// app (newest group first), dropping down from the top-right corner where
// the popups appear. Click a notification: its default action, then dismiss.
// Hover: × dismisses just that one; the group's × clears the app.
// Header: count, do-not-disturb switch, clear all. Escape / click outside closes.
PanelWindow {
    id: nc

    required property var server        // NotificationServer
    required property var owner         // Notifications.qml root (arrival times)
    property bool open: false

    readonly property int fontSize: 13
    readonly property var all: server.trackedNotifications.values

    // newest first, grouped by app, groups ordered by their newest item
    readonly property var groups: {
        const map = {}, order = [];
        for (const n of all) {
            const k = n.appName || "notification";
            if (!map[k]) { map[k] = []; order.push(k); }
            map[k].push(n);
        }
        const t = n => nc.owner.arrived[n.id] || 0;
        return order.map(k => ({ app: k, items: map[k].slice().sort((a, b) => t(b) - t(a)) }))
                    .sort((a, b) => t(b.items[0]) - t(a.items[0]));
    }

    // "now", "5 min", "2 h", "yesterday", "3 d"
    property real now: Date.now()
    Timer { interval: 30000; running: nc.open; repeat: true; triggeredOnStart: true; onTriggered: nc.now = Date.now() }
    function ago(n) {
        const t = owner.arrived[n.id];
        if (!t) return "";
        const s = (now - t) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + " min";
        if (s < 86400) return Math.floor(s / 3600) + " h";
        return s < 172800 ? "yesterday" : Math.floor(s / 86400) + " d";
    }

    onOpenChanged: if (open) { drop.from(-18); Qt.callLater(() => keys.forceActiveFocus()) }

    screen: {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        for (const s of Quickshell.screens) if (s.name === name) return s;
        return Quickshell.screens[0];
    }
    // Always mapped (invisible and click-through while closed), like the other panels
    visible: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "horizon-notifcenter"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.right: true
    margins.top: 6
    margins.right: 6
    implicitWidth: 430
    implicitHeight: Math.min(panel.implicitHeight, Math.round((screen ? screen.height : 1200) * 0.75)) + 24
    mask: Region { item: nc.open ? panel : null }
    color: "transparent"

    // Click outside closes; armed after opening (see Launcher.qml)
    HyprlandFocusGrab {
        id: grab
        windows: [nc]
        active: false
        onCleared: if (nc.open) nc.open = false
    }
    Timer { id: armGrab; interval: 60; onTriggered: grab.active = nc.open }
    Connections {
        target: nc
        function onOpenChanged() { if (nc.open) armGrab.restart(); else grab.active = false }
    }

    Rectangle {
        id: panel
        x: 10
        y: 10
        width: parent.width - 20
        height: Math.min(implicitHeight, nc.height - 24)
        implicitHeight: header.height + (nc.all.length === 0 ? emptyText.height + 24 : list.contentHeight + 12) + 8
        radius: 10
        clip: true
        color: Theme.alpha(Theme.surface, Theme.popupAlpha)
        border.color: Theme.border
        border.width: 1

        Spring { id: drop; preset: Theme.springs.rise; to: 0 }
        transform: Translate { y: drop.value }
        opacity: nc.open ? Math.min(1, 2 * (1 + drop.value / 18)) : (warmedUp ? 0 : 0.01)
        Behavior on opacity { enabled: !nc.open; NumberAnimation { duration: 90 } }
        property bool warmedUp: false
        Timer { running: true; interval: 1000; onTriggered: panel.warmedUp = true }

        Item {
            id: keys
            focus: nc.open
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { nc.open = false; event.accepted = true }
            }
        }

        // ── Header ──
        Item {
            id: header
            width: parent.width
            height: 44

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: "NOTIFICATIONS" + (nc.all.length ? "&nbsp;&nbsp;<font color='" + Theme.muted + "'>" + nc.all.length + "</font>" : "")
                font.family: Theme.font
                font.pixelSize: nc.fontSize * 0.8
                font.letterSpacing: 1.5
                color: Theme.dim
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                // do not disturb switch (click area over the whole thing)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: dndRow.implicitWidth
                    implicitHeight: dndRow.implicitHeight
                Row {
                    id: dndRow
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "dnd"
                        font.family: Theme.font
                        font.pixelSize: nc.fontSize * 0.85
                        color: Status.dnd ? Theme.amber : Theme.dim
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 14; radius: 7
                        color: Status.dnd ? Theme.alpha(Theme.amber, 0.25) : Theme.raised
                        border.width: 1
                        border.color: Status.dnd ? Theme.amber : Theme.border
                        Spring { id: knob; preset: Theme.springs.settle; to: Status.dnd ? 14 : 2 }
                        Rectangle {
                            x: knob.value
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10; radius: 5
                            color: Status.dnd ? Theme.amber : Theme.muted
                        }
                    }
                }
                    MouseArea { anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleDnd() }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: nc.all.length > 0
                    text: "clear all"
                    font.family: Theme.font
                    font.pixelSize: nc.fontSize * 0.85
                    color: clearMouse.containsMouse ? Theme.fg : Theme.muted
                    MouseArea { id: clearMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: nc.owner.clearAll() }
                }
            }

            Rectangle { anchors.bottom: parent.bottom; x: 12; width: parent.width - 24; height: 1; color: Theme.line }
        }

        Text {
            id: emptyText
            visible: nc.all.length === 0
            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 40
            verticalAlignment: Text.AlignVCenter
            text: Status.dnd ? "no notifications  ·  do not disturb is on" : "no notifications"
            font.family: Theme.font
            font.pixelSize: nc.fontSize * 0.9
            color: Theme.dim
        }

        // ── Groups ──
        Flickable {
            id: list
            visible: nc.all.length > 0
            anchors.top: header.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: parent.width
            contentHeight: groupsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: groupsCol
                width: list.width
                spacing: 6

                Repeater {
                    model: nc.groups

                    delegate: Column {
                        id: group
                        required property var modelData
                        width: groupsCol.width
                        spacing: 2

                        // app name · count · × clear the app
                        Item {
                            width: parent.width
                            height: 28
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: group.modelData.app.toUpperCase() + (group.modelData.items.length > 1 ? "  " + group.modelData.items.length : "")
                                font.family: Theme.font
                                font.pixelSize: nc.fontSize * 0.75
                                font.letterSpacing: 1.2
                                color: Theme.dim
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                font.family: Theme.font
                                font.pixelSize: nc.fontSize
                                color: groupX.containsMouse ? Theme.fg : Theme.dim
                                MouseArea { id: groupX; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { for (const n of group.modelData.items.slice()) n.dismiss() } }
                            }
                        }

                        Repeater {
                            model: group.modelData.items
                            delegate: Item {
                                id: item
                                required property var modelData
                                readonly property var n: modelData
                                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                                readonly property var defaultAction: n.actions.find(a => a.identifier === "default") ?? null
                                width: group.width
                                height: body.implicitHeight + 18

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    radius: 6
                                    color: hover.containsMouse ? Theme.hover : "transparent"
                                }
                                // critical: a red mark on the left
                                Rectangle {
                                    visible: item.critical
                                    x: 9; y: 8; width: 2; height: parent.height - 16; radius: 1
                                    color: Theme.red
                                }

                                Column {
                                    id: body
                                    x: 16
                                    y: 9
                                    width: parent.width - 32 - 28
                                    spacing: 2
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            id: title
                                            width: Math.min(implicitWidth, parent.width - when.implicitWidth - 8)
                                            text: item.n.summary
                                            elide: Text.ElideRight
                                            font.family: Theme.font
                                            font.pixelSize: nc.fontSize
                                            color: item.critical ? Theme.red : Theme.fg
                                        }
                                        Text {
                                            id: when
                                            text: nc.ago(item.n)
                                            font.family: Theme.font
                                            font.pixelSize: nc.fontSize * 0.8
                                            color: Theme.dim
                                            anchors.baseline: title.baseline
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: item.n.body
                                        textFormat: Text.StyledText
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        font.family: Theme.font
                                        font.pixelSize: nc.fontSize * 0.92
                                        color: Theme.muted
                                        linkColor: Theme.accent
                                    }
                                }

                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (item.defaultAction) item.defaultAction.invoke(); item.n.dismiss() }
                                }

                                Text {   // × dismiss this one (on hover)
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    visible: hover.containsMouse || dismissX.containsMouse
                                    text: "×"
                                    font.family: Theme.font
                                    font.pixelSize: nc.fontSize
                                    color: dismissX.containsMouse ? Theme.fg : Theme.muted
                                    MouseArea { id: dismissX; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor; onClicked: item.n.dismiss() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
