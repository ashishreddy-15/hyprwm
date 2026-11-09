import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Month calendar that rises out of the bar when the clock is clicked.
// Today: bright, with the horizon line under it. Other months' days: dim.
// ‹ › or scrolling changes the month; clicking the month name returns to today.
// Escape or clicking outside closes it.
PanelWindow {
    id: cal

    required property var bar          // the bar PanelWindow this belongs to
    property bool open: false

    readonly property int fontSize: bar.fontSize
    readonly property int cell: Math.round(fontSize * 2.3)
    readonly property int firstDow: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday

    // The month being viewed (always the 1st)
    property date view: new Date()
    function resetView() { const d = new Date(); view = new Date(d.getFullYear(), d.getMonth(), 1) }
    function shift(months) { view = new Date(view.getFullYear(), view.getMonth() + months, 1) }

    onOpenChanged: if (open) { resetView(); rise.restart(); Qt.callLater(() => keys.forceActiveFocus()) }

    // 6 weeks of dates, starting on the locale's first weekday
    readonly property var days: {
        const first = new Date(view.getFullYear(), view.getMonth(), 1);
        const offset = (first.getDay() - firstDow + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(view.getFullYear(), view.getMonth(), 1 - offset + i));
        return out;
    }

    SystemClock { id: clock; precision: SystemClock.Hours }
    function isToday(d) {
        const t = clock.date;
        return d.getDate() === t.getDate() && d.getMonth() === t.getMonth() && d.getFullYear() === t.getFullYear();
    }

    screen: bar.screen
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "horizon-calendar"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: bar.islandHeight + 4 + 10
    implicitWidth: cell * 7 + 32
    implicitHeight: panel.implicitHeight
    color: "transparent"

    // Clicking the bar (e.g. the clock again) doesn't count as "outside"
    HyprlandFocusGrab {
        windows: [cal, cal.bar]
        active: cal.visible
        onCleared: cal.open = false
    }

    Rectangle {
        id: panel
        width: parent.width
        implicitHeight: body.implicitHeight + 28
        radius: 10
        color: Theme.alpha(Theme.surface, 0.95)
        border.color: Theme.border
        border.width: 1

        property real lift: 0
        transform: Translate { y: panel.lift }
        NumberAnimation { id: rise; target: panel; property: "lift"; from: 14; to: 0; duration: Theme.normal; easing.type: Easing.OutQuint }

        Item {
            id: keys
            focus: cal.open
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) cal.open = false;
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cal.shift(-1);
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cal.shift(1);
                else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) cal.resetView();
                else return;
                event.accepted = true;
            }
        }

        WheelHandler {
            onWheel: event => cal.shift(event.angleDelta.y > 0 ? -1 : 1)
        }

        Column {
            id: body
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 10

            // Header: ‹  November 2026  ›
            Item {
                width: parent.width
                height: cal.fontSize * 1.8

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    font.family: Theme.font
                    font.pixelSize: cal.fontSize * 1.3
                    color: prevMouse.containsMouse ? Theme.fg : Theme.dim
                    MouseArea { id: prevMouse; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(-1) }
                }
                Text {
                    anchors.centerIn: parent
                    text: cal.view.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    font.family: Theme.font
                    font.pixelSize: cal.fontSize
                    color: Theme.fg
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.resetView() }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    font.family: Theme.font
                    font.pixelSize: cal.fontSize * 1.3
                    color: nextMouse.containsMouse ? Theme.fg : Theme.dim
                    MouseArea { id: nextMouse; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(1) }
                }
            }

            // Weekday initials
            Row {
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: cal.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((cal.firstDow + index) % 7, Locale.ShortFormat).slice(0, 2)
                        font.family: Theme.font
                        font.pixelSize: cal.fontSize * 0.8
                        font.letterSpacing: 0.5
                        color: Theme.dim
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            // Days
            Grid {
                columns: 7
                Repeater {
                    model: cal.days
                    Item {
                        id: day
                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === cal.view.getMonth()
                        readonly property bool today: cal.isToday(modelData)
                        readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6
                        width: cal.cell
                        height: Math.round(cal.cell * 0.9)

                        Text {
                            anchors.centerIn: parent
                            text: day.modelData.getDate()
                            font.family: Theme.font
                            font.pixelSize: cal.fontSize * 0.95
                            color: day.today ? Theme.fg
                                 : !day.inMonth ? Theme.alpha(Theme.dim, 0.6)
                                 : day.weekend ? Theme.dim : Theme.muted
                        }
                        // the horizon line under today
                        Rectangle {
                            visible: day.today
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: parent.width * 0.7
                            height: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                                GradientStop { position: 0.5; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                            }
                        }
                    }
                }
            }

            // Today, spelled out
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clock.date.toLocaleDateString(Qt.locale(), "dddd d MMMM").toUpperCase()
                font.family: Theme.font
                font.pixelSize: cal.fontSize * 0.75
                font.letterSpacing: 2
                color: Theme.dim
            }
        }
    }
}
