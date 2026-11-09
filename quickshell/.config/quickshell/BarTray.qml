import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Tray drawer: "···" opens the tray icons inline (as in the Sway bar).
// Left click activates an item, right click opens its menu (TrayMenu.qml).
Item {
    id: root

    required property var barWindow
    property int fontSize: 13
    property bool open: false

    implicitWidth: row.implicitWidth
    implicitHeight: fontSize * 1.4

    // Menus drawn in the Horizon style (item.display() would use Qt's default look)
    TrayMenu { id: trayMenu; fontSize: root.fontSize }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.fontSize * 0.7)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(root.fontSize * 0.6)
            visible: root.open

            Repeater {
                model: SystemTray.items.values

                delegate: IconImage {
                    id: icon
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: root.fontSize + 2
                    source: modelData.icon

                    // Muted like the launcher; full colour while hovered
                    opacity: iconMouse.containsMouse ? 1 : 0.75
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        saturation: iconMouse.containsMouse ? 0 : -1
                        Behavior on saturation { NumberAnimation { duration: Theme.fast } }
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                    MouseArea {
                        id: iconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const item = icon.modelData;
                            if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) trayMenu.openAt(root.barWindow, icon, item.menu);
                            } else {
                                item.activate();
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "···"
            font.family: Theme.font
            font.pixelSize: root.fontSize
            color: root.open ? Theme.muted : Theme.dim

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open = !root.open
            }
        }
    }
}
