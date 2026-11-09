import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Workspace overview (Super+O): the focused screen's workspaces as small live
// screens along the photo's horizon band, over the dimmed, blurred wallpaper.
//
//   ← → / h l    choose          ↵  go           1…0  jump to that workspace
//   click card   go there        click a window  focus it
//   drag window  onto another card to move it there (stays open)
//   esc / Super+O / click the background   close
//
// Live previews (ScreencopyView) run only while open. The last card, "new",
// goes to the first free workspace in this screen's range (1–5 Samsung,
// 6–10 laptop; see hypr/modules/monitors.lua).
Scope {
    id: root

    property bool open: false
    property int selected: 0
    property var monitor: null          // HyprlandMonitor, frozen at open
    property var dragWin: null          // HyprlandToplevel being dragged

    // ── Data ──
    readonly property var spaces: {
        if (!monitor) return [];
        return Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor && w.monitor.name === monitor.name)
            .sort((a, b) => a.id - b.id);
    }
    readonly property int newId: {
        const taken = Hyprland.workspaces.values.map(w => w.id);
        const lo = monitor && monitor.name.startsWith("eDP") ? 6 : 1;
        for (let i = lo; i < lo + 5; i++) if (taken.indexOf(i) < 0) return i;
        return Math.max(10, ...taken) + 1;
    }
    // cards: real workspaces + "new"
    readonly property var cards: spaces.map(w => ({ id: w.id, ws: w })).concat([{ id: newId, ws: null }])

    function windowsOf(ws) {
        if (!ws) return [];
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === ws.id && t.lastIpcObject && t.lastIpcObject.at);
    }

    function show() {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        monitor = Hyprland.focusedMonitor;
        const cur = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1;
        selected = Math.max(0, cards.findIndex(c => c.id === cur));
        open = true;
        rise.from(28);
        Qt.callLater(() => keys.forceActiveFocus());
    }
    function hide() { open = false; dragWin = null }
    function toggle() { if (open) hide(); else show() }

    // Hyprland wants "address:0x…"; don't depend on how the address is reported
    function addr(t) { const a = String(t.address || ""); return a.startsWith("0x") ? a : "0x" + a }

    function go(id) {
        hide();
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }
    function focusWindow(t) {
        hide();
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr(t) + "\" })");
    }
    function moveWindow(t, id) {
        if (!t || (t.workspace && t.workspace.id === id)) return;
        Hyprland.dispatch("hl.dsp.window.move({ window = \"address:" + addr(t) + "\", workspace = " + id + ", follow = false })");
        refresh.restart();
    }
    Timer { id: refresh; interval: 150; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() } }

    PanelWindow {
        id: win

        screen: {
            const name = root.monitor ? root.monitor.name : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
            for (const s of Quickshell.screens) if (s.name === name) return s;
            return Quickshell.screens[0];
        }
        readonly property bool laptop: screen && screen.name.startsWith("eDP")
        readonly property int fontSize: laptop ? 14 : 12

        // Always mapped (invisible and click-through while closed), like the other panels
        visible: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-overview"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region { item: root.open ? content : null }
        color: "transparent"

        // Card size: up to ~18% of the screen width, smaller when there are many
        readonly property real gap: Math.round(width * 0.014)
        readonly property real cardW: Math.min(width * 0.18, (width * 0.9 - gap * (root.cards.length - 1)) / Math.max(1, root.cards.length))
        readonly property real cardH: root.monitor ? cardW * root.monitor.height / root.monitor.width : cardW * 0.625

        Item {
            id: content
            anchors.fill: parent
            opacity: root.open ? 1 : (warmedUp ? 0 : 0.01)
            Behavior on opacity { NumberAnimation { duration: root.open ? 180 : 110; easing.type: Easing.OutCubic } }
            property bool warmedUp: false
            Timer { running: true; interval: 1200; onTriggered: content.warmedUp = true }

            // ── Backdrop: the wallpaper, dimmed and softly blurred ──
            // A pre-blurred copy (Theme.wallpaperBlur): a live MultiEffect blur
            // rendered the horizon as an offset red smear, and costs GPU on open.
            Rectangle { anchors.fill: parent; color: Theme.ground }
            Image {
                anchors.fill: parent
                source: Theme.wallpaperBlur
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MouseArea { anchors.fill: parent; onClicked: root.hide() }

            Item {
                id: keys
                focus: root.open
                Keys.onPressed: event => {
                    const k = event.key, n = root.cards.length;
                    if (k === Qt.Key_Escape) root.hide();
                    else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) root.selected = Math.min(n - 1, root.selected + 1);
                    else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) root.selected = Math.max(0, root.selected - 1);
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.go(root.cards[root.selected].id);
                    else if (k >= Qt.Key_0 && k <= Qt.Key_9) root.go(k === Qt.Key_0 ? 10 : k - Qt.Key_0);
                    else return;
                    event.accepted = true;
                }
            }

            // ── The row of workspaces, on the horizon band ──
            Spring { id: rise; preset: Theme.springs.rise; to: 0 }

            Row {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.5 - win.cardH * 0.62)
                spacing: win.gap
                transform: Translate { y: rise.value }

                Repeater {
                    model: root.cards

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property var ws: modelData.ws
                        readonly property bool isNew: ws === null
                        readonly property bool isSelected: root.selected === index
                        readonly property bool isCurrent: !isNew && root.monitor && root.monitor.activeWorkspace
                                                          && root.monitor.activeWorkspace.id === ws.id
                        readonly property var wins: root.windowsOf(ws)

                        width: win.cardW
                        height: win.cardH + win.fontSize * 2.6

                        Spring { id: lift; preset: Theme.springs.settle; to: card.isSelected ? -win.fontSize * 0.8 : 0 }
                        transform: Translate { y: lift.value }

                        // the small screen
                        Rectangle {
                            id: scr
                            width: parent.width
                            height: win.cardH
                            radius: 6
                            clip: true
                            color: card.isNew ? Theme.alpha(Theme.bg, 0.6) : Theme.ground
                            border.width: 1
                            border.color: drop.containsDrag ? Theme.accent
                                        : card.isSelected ? Theme.alpha(Theme.accent, 0.8) : Theme.alpha(Theme.border, 0.9)

                            // its own wallpaper, then the windows on top
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: !card.isNew
                                source: Theme.wallpaper
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Math.round(win.cardW)
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.isNew
                                text: "new"
                                font.family: Theme.font
                                font.pixelSize: win.fontSize
                                font.letterSpacing: 2
                                color: Theme.muted
                            }

                            Repeater {
                                model: card.wins
                                delegate: Item {
                                    id: tile
                                    required property var modelData
                                    readonly property var t: modelData
                                    readonly property var ipc: t.lastIpcObject
                                    readonly property real sx: scr.width / root.monitor.width
                                    readonly property real sy: scr.height / root.monitor.height
                                    x: (ipc.at[0] - root.monitor.x) * sx
                                    y: (ipc.at[1] - root.monitor.y) * sy
                                    width: Math.max(8, ipc.size[0] * sx)
                                    height: Math.max(6, ipc.size[1] * sy)
                                    opacity: root.dragWin === t ? 0.35 : 1

                                    Rectangle {   // window border, as on the desktop
                                        anchors.fill: parent
                                        radius: 3
                                        color: Theme.bg
                                        border.width: 1
                                        border.color: t.activated ? Theme.accent : Theme.border
                                    }
                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: root.open ? tile.t.wayland : null
                                        live: root.open
                                    }
                                    // fallback when there's no capture: the app icon
                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: !shot.hasContent
                                        implicitSize: Math.min(parent.width, parent.height) * 0.4
                                        source: Quickshell.iconPath(tile.ipc.class || "", "application-x-executable")
                                        opacity: 0.7
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        property point start
                                        property bool dragging: false
                                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); dragging = false }
                                        onPositionChanged: mouse => {
                                            if (!pressed) return;
                                            if (!dragging && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 6) {
                                                dragging = true;
                                                root.dragWin = tile.t;
                                                ghost.width = tile.width; ghost.height = tile.height;
                                            }
                                            if (dragging) {
                                                const p = mapToItem(content, mouse.x, mouse.y);
                                                ghost.x = p.x - ghost.width / 2; ghost.y = p.y - ghost.height / 2;
                                            }
                                        }
                                        onReleased: {
                                            if (dragging) { ghost.Drag.drop(); root.dragWin = null; dragging = false }
                                            else root.focusWindow(tile.t);
                                        }
                                    }
                                }
                            }

                            DropArea {
                                id: drop
                                anchors.fill: parent
                                keys: ["window"]
                                onDropped: root.moveWindow(root.dragWin, card.modelData.id)
                            }

                            MouseArea {   // the card itself (behind the windows)
                                anchors.fill: parent
                                z: -1
                                onClicked: root.go(card.modelData.id)
                            }
                        }

                        // number + apps, the horizon line under the current one
                        Row {
                            anchors.top: scr.bottom
                            anchors.topMargin: Math.round(win.fontSize * 0.7)
                            width: parent.width
                            spacing: Math.round(win.fontSize * 0.7)
                            Text {
                                text: card.modelData.id
                                font.family: Theme.font
                                font.pixelSize: win.fontSize
                                color: card.isCurrent ? Theme.fg : Theme.muted
                            }
                            Text {
                                width: parent.width - win.fontSize * 2
                                elide: Text.ElideRight
                                text: card.isNew ? "empty" : card.wins.map(w => w.lastIpcObject.class || "").filter(s => s).join(", ")
                                font.family: Theme.font
                                font.pixelSize: win.fontSize
                                color: Theme.dim
                            }
                        }
                        Rectangle {
                            visible: card.isCurrent
                            x: 0
                            y: scr.height + win.fontSize * 2.3
                            width: win.fontSize * 2
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

            // the window being dragged
            Rectangle {
                id: ghost
                visible: root.dragWin !== null
                radius: 3
                color: Theme.alpha(Theme.surface, 0.9)
                border.width: 1
                border.color: Theme.accent
                Drag.active: visible
                Drag.keys: ["window"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
            }

            // hints
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.08)
                spacing: win.fontSize * 2
                opacity: 0.9
                Repeater {
                    model: [["← →", "choose"], ["↵", "go"], ["1…0", "jump"], ["drag", "move a window"], ["esc", "close"]]
                    Row {
                        required property var modelData
                        spacing: 6
                        Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: win.fontSize * 0.85; color: Theme.muted }
                        Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: win.fontSize * 0.85; color: Theme.dim }
                    }
                }
            }
        }

        // click outside / focus loss closes; armed after opening (see Launcher.qml)
        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: false
            onCleared: if (root.open) root.hide()
        }
        Timer { id: armGrab; interval: 60; onTriggered: grab.active = root.open }
        Connections {
            target: root
            function onOpenChanged() { if (root.open) armGrab.restart(); else grab.active = false }
        }
    }
}
