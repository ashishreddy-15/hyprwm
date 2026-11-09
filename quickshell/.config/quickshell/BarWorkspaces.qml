import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspaces of one monitor: occupied ones plus the active one (empty ones
// stay hidden). Dots under a number = windows on it (up to 3). The horizon
// line glides under the active workspace.
Item {
    id: root

    required property var monitor     // HyprlandMonitor of this bar's screen
    property int fontSize: 13

    // Centre of the active workspace, in this item's coordinates (for the glow edge)
    readonly property real activeCenter: activeItem ? activeItem.x + activeItem.width / 2 : -1
    property Item activeItem: null

    readonly property var spaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && monitor && w.monitor.name === monitor.name
                     && (w.active || w.toplevels.values.length > 0))
        .sort((a, b) => a.id - b.id)

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : fontSize * 2

    // Keeps one delegate per workspace across updates, so the row can animate
    // numbers making room instead of rebuilding (a plain JS array would)
    ScriptModel { id: spaceModel; values: root.spaces }

    Row {
        id: row
        height: parent.height

        // a workspace appearing fades in; the others slide aside
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic } }
        move: Transition { NumberAnimation { properties: "x"; duration: 260; easing.type: Easing.OutCubic } }

        Repeater {
            model: spaceModel

            delegate: Item {
                id: ws
                required property var modelData
                readonly property bool isActive: modelData.active
                readonly property int windows: modelData.toplevels.values.length

                width: label.implicitWidth + root.fontSize * 1.1
                height: root.height

                onIsActiveChanged: if (isActive) root.activeItem = ws
                Component.onCompleted: if (isActive) root.activeItem = ws
                Component.onDestruction: if (root.activeItem === ws) root.activeItem = null

                // Number on the same line as the clock; window dots just below it
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: ws.modelData.id
                    font.family: Theme.font
                    font.pixelSize: root.fontSize
                    color: ws.modelData.urgent ? Theme.red
                         : ws.isActive ? Theme.fg
                         : ws.windows > 0 ? Theme.muted : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.height - 7
                    spacing: 2
                    Repeater {
                        model: Math.min(ws.windows, 3)
                        Rectangle { width: 2; height: 2; radius: 1; color: label.color; opacity: 0.7 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.modelData.id + " })")
                }
            }
        }
    }

    // The horizon line under the active workspace glides between numbers
    Spring { id: lineX; preset: Theme.springs.glide; to: root.activeItem ? root.activeItem.x + 3 : 0 }
    Spring { id: lineW; preset: Theme.springs.glide; to: root.activeItem ? root.activeItem.width - 6 : 0 }
    Rectangle {
        visible: root.activeItem !== null
        height: 1
        y: root.height - 3
        x: lineX.value
        width: lineW.value
        opacity: root.monitor && root.monitor.focused ? 1 : 0.45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
            GradientStop { position: 0.5; color: Theme.accent }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }
}
