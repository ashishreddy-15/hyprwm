import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland

// Power panel: click the battery meter (as in the Sway bar).
//   power profile   Power saver / Balanced / Performance   (tuned-ppd)
//   keep awake      no auto-lock, screen-off or suspend    (keep-awake.sh)
//   battery         percentage · time left · power draw
// Keys: s / b / p pick a profile, a toggles keep awake, j/k or arrows and
// Enter, Escape closes. Rises out of the bar under the island's right end.
PanelWindow {
    id: pp

    required property var bar
    property bool open: false
    property int selected: 1

    readonly property int fontSize: bar.fontSize
    readonly property int rowHeight: Math.round(fontSize * 2.4)

    // rows: three profiles, then keep awake
    readonly property var profiles: [
        { key: "s", label: "Power saver", value: PowerProfile.PowerSaver },
        { key: "b", label: "Balanced",    value: PowerProfile.Balanced },
        { key: "p", label: "Performance", value: PowerProfile.Performance },
    ].filter(p => p.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
    readonly property int awakeRow: profiles.length

    function pick(i) {
        selected = i;
        if (i < profiles.length) PowerProfiles.profile = profiles[i].value;
        else Status.toggleKeepAwake();
    }

    onOpenChanged: if (open) {
        selected = Math.max(0, profiles.findIndex(p => p.value === PowerProfiles.profile));
        rise.from(20);
        Qt.callLater(() => keys.forceActiveFocus());
    }

    // Battery line: "43%  ·  2 h 10 min left  ·  7.8 W"
    readonly property var battery: UPower.displayDevice
    function duration(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
    readonly property string batteryLine: {
        const b = battery;
        if (!b || !b.isLaptopBattery) return "";
        const pct = Math.round(b.percentage > 1 ? b.percentage : b.percentage * 100) + "%";
        const parts = [pct];
        if (UPower.onBattery && b.timeToEmpty > 0) parts.push(duration(b.timeToEmpty) + " left");
        else if (!UPower.onBattery && b.timeToFull > 0) parts.push(duration(b.timeToFull) + " to full");
        if (b.changeRate > 0) parts.push(b.changeRate.toFixed(1) + " W");
        return parts.join("  ·  ");
    }

    screen: bar.screen
    // Always mapped (invisible and click-through while closed), like the other panels
    visible: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "horizon-powerpanel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    anchors.right: true
    // right edge lines up with the island's right edge; 20 px room to rise through
    margins.right: Math.round((bar.screen.width - bar.implicitWidth) / 2)
    margins.bottom: bar.islandHeight + 4 - 10
    implicitWidth: Math.round(fontSize * 22)
    implicitHeight: panel.implicitHeight + 20
    mask: Region { item: pp.open ? panel : null }
    color: "transparent"

    // Click outside closes; armed after opening (see Launcher.qml)
    HyprlandFocusGrab {
        id: grab
        windows: [pp, pp.bar]
        active: false
        onCleared: if (pp.open) pp.open = false
    }
    Timer { id: armGrab; interval: 60; onTriggered: grab.active = pp.open }
    Connections {
        target: pp
        function onOpenChanged() { if (pp.open) armGrab.restart(); else grab.active = false }
    }

    Rectangle {
        id: panel
        width: parent.width
        implicitHeight: body.implicitHeight + 16
        radius: 10
        color: Theme.alpha(Theme.surface, Theme.popupAlpha)
        border.color: Theme.border
        border.width: 1

        Spring { id: rise; preset: Theme.springs.rise; to: 0 }
        transform: Translate { y: rise.value }
        opacity: pp.open ? Math.min(1, 2 * (1 - rise.value / 20)) : (warmedUp ? 0 : 0.01)
        Behavior on opacity { enabled: !pp.open; NumberAnimation { duration: 90 } }
        property bool warmedUp: false
        Timer { running: true; interval: 1000; onTriggered: panel.warmedUp = true }

        Item {
            id: keys
            focus: pp.open
            Keys.onPressed: event => {
                const k = event.key;
                const last = pp.awakeRow;
                if (k === Qt.Key_Escape) pp.open = false;
                else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) pp.selected = Math.min(last, pp.selected + 1);
                else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) pp.selected = Math.max(0, pp.selected - 1);
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) pp.pick(pp.selected);
                else if (event.text.toLowerCase() === "a") pp.pick(last);
                else {
                    const i = pp.profiles.findIndex(p => p.key === event.text.toLowerCase());
                    if (i >= 0) pp.pick(i); else return;
                }
                event.accepted = true;
            }
        }

        Column {
            id: body
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2

            Text {
                leftPadding: 12
                topPadding: 4
                bottomPadding: 4
                text: "POWER PROFILE"
                font.family: Theme.font
                font.pixelSize: pp.fontSize * 0.72
                font.letterSpacing: 1.5
                color: Theme.dim
            }

            Repeater {
                model: pp.profiles
                delegate: PanelRow {
                    owner: pp
                    width: body.width
                    required property var modelData
                    required property int index
                    rowIndex: index
                    label: modelData.label
                    hint: modelData.key
                    active: PowerProfiles.profile === modelData.value
                    // Performance draws more power: amber, like PERF in the bar
                    activeColor: modelData.value === PowerProfile.Performance ? Theme.amber : Theme.accent
                }
            }

            Rectangle { width: parent.width; height: 9; color: "transparent"
                Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.line } }

            PanelRow {
                owner: pp
                width: body.width
                rowIndex: pp.awakeRow
                label: "Keep awake"
                hint: "a"
                isSwitch: true
                active: Status.keepAwake
                activeColor: Theme.amber
            }

            Text {
                visible: pp.batteryLine !== ""
                width: parent.width
                leftPadding: 12
                topPadding: 8
                bottomPadding: 2
                text: pp.batteryLine
                font.family: Theme.font
                font.pixelSize: pp.fontSize * 0.8
                color: Theme.dim
            }
        }
    }

    // A selectable row: radio dot (profiles) or a small switch (keep awake)
    component PanelRow: Item {
        id: row
        property var owner                 // the PowerPanel (inline components can't see its id)
        property int rowIndex: 0
        property string label: ""
        property string hint: ""
        property bool active: false
        property bool isSwitch: false
        property color activeColor: Theme.accent
        readonly property bool isSelected: row.owner.selected === rowIndex

        height: row.owner.rowHeight

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: row.isSelected ? Theme.raised : mouse.containsMouse ? Theme.hover : "transparent"
        }
        Rectangle {
            visible: row.isSelected
            x: 30
            width: Math.min(parent.width * 0.4, 110)
            anchors.bottom: parent.bottom
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                GradientStop { position: 0.5; color: Theme.accent }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
            }
        }

        // radio dot
        Rectangle {
            visible: !row.isSwitch
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: row.active ? row.activeColor : "transparent"
            border.width: 1
            border.color: row.active ? row.activeColor : Theme.dim
        }

        Text {
            x: row.isSwitch ? 12 : 30
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: Theme.font
            font.pixelSize: row.owner.fontSize
            color: row.active ? (row.activeColor === Theme.amber ? Theme.amber : Theme.fg)
                 : row.isSelected ? Theme.fg : Theme.muted
        }

        // switch (keep awake)
        Rectangle {
            id: sw
            visible: row.isSwitch
            anchors.right: hintText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 14; radius: 7
            color: row.active ? Theme.alpha(row.activeColor, 0.25) : Theme.raised
            border.width: 1
            border.color: row.active ? row.activeColor : Theme.border
            Spring { id: knob; preset: Theme.springs.settle; to: row.active ? 14 : 2 }
            Rectangle {
                x: knob.value
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10; radius: 5
                color: row.active ? row.activeColor : Theme.muted
            }
        }

        Text {
            id: hintText
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.hint
            font.family: Theme.font
            font.pixelSize: row.owner.fontSize * 0.85
            color: Theme.dim
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.owner.pick(row.rowIndex)
        }
    }
}
