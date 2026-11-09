import QtQuick
import Quickshell
import Quickshell.Widgets

// One level of a TrayMenu. Entries with children expand inline below
// themselves by loading another TrayMenuLevel (indented one step).
Column {
    id: level
    property var owner: null          // the TrayMenu (shared state: expanded, maxLabel, close())
    property var menu: null           // QsMenuHandle, or a QsMenuEntry with children
    property int depth: 0
    width: parent ? parent.width : 0

    QsMenuOpener { id: opener; menu: level.menu }

    Repeater {
        model: opener.children

        delegate: Column {
            id: entryCol
            required property var modelData
            readonly property var entry: modelData
            readonly property bool open: level.owner.expanded[entry] === true
            width: level.width

            // Separator
            Rectangle {
                visible: entryCol.entry.isSeparator
                width: parent.width
                height: 9
                color: "transparent"
                Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.line }
            }

            // Entry
            Item {
                id: rowItem
                visible: !entryCol.entry.isSeparator
                width: parent.width
                height: Math.round(level.owner.fontSize * 2.2)

                readonly property bool hovered: mouse.containsMouse && entryCol.entry.enabled
                readonly property bool checkable: entryCol.entry.buttonType !== QsMenuButtonType.None
                readonly property bool checked: entryCol.entry.checkState === Qt.Checked

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: rowItem.hovered ? Theme.raised : "transparent"
                }
                Rectangle {
                    visible: rowItem.hovered
                    x: 26 + level.depth * 14
                    width: Math.min(parent.width * 0.35, 100)
                    anchors.bottom: parent.bottom
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                        GradientStop { position: 0.5; color: Theme.accent }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                    }
                }

                // check / radio mark, or the entry's icon (muted)
                Item {
                    id: mark
                    x: 8 + level.depth * 14
                    width: 14
                    height: parent.height
                    Text {
                        anchors.centerIn: parent
                        visible: rowItem.checkable && rowItem.checked
                        text: entryCol.entry.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓"
                        font.family: Theme.font
                        font.pixelSize: entryCol.entry.buttonType === QsMenuButtonType.RadioButton ? level.owner.fontSize * 0.6 : level.owner.fontSize
                        color: Theme.accent
                    }
                    IconImage {
                        anchors.centerIn: parent
                        visible: !rowItem.checkable && entryCol.entry.icon !== ""
                        implicitSize: 14
                        source: entryCol.entry.icon
                        opacity: rowItem.hovered ? 1 : 0.6
                    }
                }

                Text {
                    id: label
                    anchors.left: mark.right
                    anchors.leftMargin: 10
                    anchors.right: arrow.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: entryCol.entry.text.replace(/_(?=\S)/, "")   // drop GTK mnemonic underscores
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: level.owner.fontSize
                    color: !entryCol.entry.enabled ? Theme.dim
                         : rowItem.hovered ? Theme.fg : Theme.muted
                    Component.onCompleted: level.owner.maxLabel = Math.max(level.owner.maxLabel, implicitWidth + level.depth * 14)
                }

                Text {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entryCol.entry.hasChildren
                    text: entryCol.open ? "−" : "+"
                    font.family: Theme.font
                    font.pixelSize: level.owner.fontSize
                    color: Theme.dim
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entryCol.entry.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const e = entryCol.entry;
                        if (e.hasChildren) {
                            const x = Object.assign({}, level.owner.expanded);
                            x[e] = !entryCol.open;
                            level.owner.expanded = x;
                        } else {
                            e.triggered();
                            level.owner.close();
                        }
                    }
                }
            }

            // Inline submenu
            Loader {
                active: entryCol.entry.hasChildren && entryCol.open
                width: parent.width
                source: active ? "TrayMenuLevel.qml" : ""
                onLoaded: { item.owner = level.owner; item.menu = entryCol.entry; item.depth = level.depth + 1 }
            }
        }
    }
}
