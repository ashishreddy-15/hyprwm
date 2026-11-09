import QtQuick

// Text button for the bottom island: grey text, brightening on hover/focus
// with the horizon line (accent, fading at both ends) underneath.
Item {
    id: btn

    property alias text: label.text
    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: parent ? parent.height : 32
    activeFocusOnTab: enabled

    readonly property bool hot: enabled && (mouse.containsMouse || activeFocus)

    Text {
        id: label
        anchors.centerIn: parent
        font.family: config.font
        font.pixelSize: Math.max(12, Math.round(13 * (root ? root.u : 1)))
        color: !btn.enabled ? config.dim : btn.hot ? config.fg : config.muted
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: label.width
        height: 1
        visible: btn.hot
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: config.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabled) btn.clicked()
    }

    Keys.onReturnPressed: btn.clicked()
    Keys.onEnterPressed: btn.clicked()
    Keys.onSpacePressed: btn.clicked()
}
