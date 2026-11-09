import QtQuick

// LABEL ━━━━── 62
// A thin track whose fill runs sky → accent. `tone` overrides the fill and
// value colour for warnings (amber) and critical states (red).
Item {
    id: root

    property string label: ""
    property real fraction: 0          // 0..1
    property int value: 0
    property int fontSize: 13
    property color tone: "transparent" // transparent = normal gradient
    property bool dimmed: false        // e.g. muted

    readonly property bool toned: tone.a > 0

    signal clicked()
    signal scrolled(int steps)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: dimmed ? 0.5 : 1

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.fontSize * 0.5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.font
            font.pixelSize: root.fontSize * 0.86
            color: Theme.muted
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.fontSize * 3.2)
            height: 2
            radius: 1
            color: Theme.border

            Rectangle {
                height: parent.height
                radius: 1
                width: Math.max(0, Math.min(1, root.fraction)) * track.width
                color: root.tone
                gradient: root.toned ? null : fill
                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuint } }
            }

            Gradient {
                id: fill
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.sky }
                GradientStop { position: 1.0; color: Theme.accent }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            font.family: Theme.font
            font.pixelSize: root.fontSize
            color: root.toned ? root.tone : Theme.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
