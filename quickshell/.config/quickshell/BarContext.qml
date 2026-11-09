import QtQuick
import Quickshell
import Quickshell.Hyprland

// The slot after the workspace numbers, so the left of the island isn't
// empty and is never crowded:
//   a window is focused →  App  window title        (the focused window, on this screen)
//   otherwise           →  cpu temp · memory · pending updates, dim (BarSystemGlance.qml):
//                          an empty workspace, or the screen that doesn't have focus
// Never wider than `maxWidth`; long text ends in "…". Cross-fades between modes.
Item {
    id: root

    required property var monitor      // HyprlandMonitor of this bar
    property int fontSize: 13
    property real maxWidth: 300

    // Focused window, only if it's on this bar's screen
    readonly property var win: {
        const t = Hyprland.activeToplevel;
        if (!t || !monitor || !t.monitor || t.monitor.name !== monitor.name) return null;
        // ...and on the workspace this screen is showing (an empty workspace
        // can't take focus, so focus stays with a window on another one)
        if (!t.workspace || !monitor.activeWorkspace || t.workspace.id !== monitor.activeWorkspace.id) return null;
        if (t.workspace && t.workspace.name && t.workspace.name.startsWith("special:")) return null;
        return t;
    }
    readonly property string appId: !win ? ""
        : (win.wayland && win.wayland.appId) ? win.wayland.appId
        : (win.lastIpcObject && win.lastIpcObject.class) ? win.lastIpcObject.class : ""
    readonly property string appName: {
        if (appId === "") return "";
        const e = DesktopEntries.heuristicLookup(appId);
        return e && e.name ? e.name : appId;
    }
    // Drop the app's own name from the end ("… - YouTube - Brave Origin")
    readonly property string winTitle: {
        if (!win) return "";
        let t = (win.title || "").trim();
        for (const sep of [" - ", " — ", " – ", " · "]) {
            if (appName && t.endsWith(sep + appName)) { t = t.slice(0, -(sep + appName).length); break; }
        }
        return t === appName ? "" : t;
    }

    readonly property bool showWindow: appName !== ""
    // no window title to show (empty workspace, or this screen isn't the focused
    // one): the system glance, so the bar's left is never blank
    readonly property bool showGlance: !showWindow

    implicitHeight: fontSize * 1.4
    implicitWidth: Math.min(maxWidth, showWindow ? windowRow.implicitWidth
                                   : showGlance ? glance.implicitWidth : 0)
    width: implicitWidth
    clip: true

    BarSystemGlance {
        id: glance
        anchors.verticalCenter: parent.verticalCenter
        fontSize: root.fontSize
        active: root.showGlance
        opacity: root.showGlance ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }

    Row {
        id: windowRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.fontSize * 0.7)
        opacity: root.showWindow ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        Text {
            id: app
            text: root.appName
            font.family: Theme.font
            font.pixelSize: root.fontSize
            color: Theme.muted
        }
        Text {
            visible: text !== ""
            width: Math.max(0, Math.min(implicitWidth, root.maxWidth - app.implicitWidth - windowRow.spacing))
            text: root.winTitle
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: root.fontSize
            color: Theme.dim
        }
    }
}
