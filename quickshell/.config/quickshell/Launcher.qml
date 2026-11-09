import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Launcher: rises out of the bar on the focused screen.
//
//   Super+D       apps       type to filter; "=" → calculator, ":" → emoji
//   Super+C       calculator (qalc): Enter copies the result
//   Super+.       emoji: Enter copies it and types it into the focused window
//   Super+V       clipboard history (cliphist): Enter copies, Shift+Delete removes
//
// Keys: Up/Down or Ctrl+K/J move, Enter picks, Escape closes,
// Backspace on an empty query goes back to apps. Clicking outside closes.
//
//   qs ipc call launcher toggle
//   qs ipc call launcher open apps|calc|emoji|clipboard
//
// Menu mode (a Quickshell `dmenu` for scripts): ~/.config/hypr/scripts/qs-dmenu
// pipes options in, this writes the chosen line (or an empty line on cancel)
// to a FIFO the script is reading:
//   qs ipc call launcher dmenu PROMPT CURRENT OPTIONS_FILE OUT_FIFO
Scope {
    id: root

    property bool open: false
    property string baseMode: "apps"   // how it was opened
    property string query: ""
    property int selected: 0

    // Typing "=" or ":" first in the app search switches mode (see onTextChanged)
    readonly property string mode: baseMode
    readonly property string term: query.trim()

    function show(m) {
        if (m !== "dmenu") answer("");   // a script waiting on a menu gets "cancelled"
        baseMode = m;
        query = "";
        selected = 0;
        calcResult = "";
        input.text = "";
        open = true;
        if (m === "clipboard") clipList.running = true;
        rise.restart();
        Qt.callLater(() => input.forceActiveFocus());
    }
    function hide() { open = false; answer("") }

    IpcHandler {
        target: "launcher"
        function toggle(): void { if (root.open) root.hide(); else root.show("apps") }
        function open(mode: string): void { root.show(mode) }
        function dmenu(prompt: string, current: string, options: string, out: string): void {
            root.answer("");
            root.dmenuPrompt = prompt;
            root.dmenuCurrent = current;
            root.dmenuItems = [];
            root.dmenuOut = out;
            dmenuRead.command = ["cat", "--", options];
            dmenuRead.running = true;
            root.show("dmenu");
        }
    }

    // ── Menu mode (for scripts) ──
    property string dmenuPrompt: ""
    property string dmenuCurrent: ""
    property string dmenuOut: ""        // FIFO path while a script is waiting
    property var dmenuItems: []
    Process {
        id: dmenuRead
        stdout: StdioCollector {
            onStreamFinished: {
                root.dmenuItems = text.split("\n").filter(l => l !== "");
                const i = root.dmenuItems.indexOf(root.dmenuCurrent);
                if (i >= 0 && root.query === "") root.selected = i;
            }
        }
    }
    // Reply to the waiting script exactly once (empty = cancelled)
    function answer(text) {
        if (dmenuOut === "") return;
        const out = dmenuOut;
        dmenuOut = "";
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", text, out]);
    }
    function dmenuResults() {
        const words = term.toLowerCase().split(/\s+/).filter(w => w.length > 0);
        return dmenuItems
            .filter(l => words.every(w => l.toLowerCase().indexOf(w) >= 0))
            .map(l => ({ title: l, subtitle: l === dmenuCurrent ? "current" : "" }));
    }

    // ── Apps ──
    function appResults() {
        const q = term.toLowerCase();
        const words = q.split(/\s+/).filter(w => w.length > 0);
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            const name = (e.name || "").toLowerCase();
            let score = 0;
            if (words.length === 0) score = 1;
            else {
                const hay = name + " " + (e.genericName || "").toLowerCase() + " " + (e.keywords || []).join(" ").toLowerCase() + " " + (e.comment || "").toLowerCase();
                if (!words.every(w => hay.indexOf(w) >= 0)) continue;
                if (name.startsWith(q)) score = 100;
                else if (name.split(/[\s\-_.]+/).some(p => p.startsWith(words[0]))) score = 60;
                else if (name.indexOf(words[0]) >= 0) score = 40;
                else score = 10;
            }
            out.push({ score: score, title: e.name, subtitle: e.genericName || e.comment || "", icon: e.icon, entry: e });
        }
        out.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
        return out.slice(0, 50);
    }

    // ── Calculator ──
    property string calcResult: ""
    Timer { id: calcDebounce; interval: 120; onTriggered: root.runCalc() }
    function runCalc() {
        calc.running = false;
        if (term === "") { calcResult = ""; return; }
        calc.command = ["qalc", "-t", "-s", "autoconversion none", "--", term];
        calc.running = true;
    }
    Process {
        id: calc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.calcResult = lines.length ? lines[lines.length - 1] : "";
            }
        }
    }

    // ── Emoji ──
    property var emojis: []
    FileView {
        path: Quickshell.shellDir + "/data/emoji.tsv"
        onLoaded: {
            const list = [];
            for (const line of text().split("\n")) {
                if (line === "" || line.startsWith("#")) continue;
                const f = line.split("\t");
                list.push({ glyph: f[0], name: f[1], keywords: (f[2] || "").toLowerCase() });
            }
            root.emojis = list;
        }
    }
    function emojiResults() {
        const words = term.toLowerCase().split(/\s+/).filter(w => w.length > 0);
        const out = [];
        for (const e of emojis) {
            if (words.length && !words.every(w => e.name.indexOf(w) >= 0 || e.keywords.indexOf(w) >= 0)) continue;
            out.push({ glyph: e.glyph, title: e.name, subtitle: "" });
            if (out.length >= 80) break;
        }
        return out;
    }

    // ── Clipboard ──
    property var clips: []
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const preview = line.slice(tab + 1);
                    const image = preview.startsWith("[[ binary data");
                    list.push({ line: line, title: image ? preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : preview.replace(/\s+/g, " "),
                                subtitle: image ? "image" : "", image: image });
                }
                root.clips = list;
            }
        }
    }
    function clipResults() {
        const q = term.toLowerCase();
        return clips.filter(c => q === "" || c.title.toLowerCase().indexOf(q) >= 0).slice(0, 100);
    }

    // ── Results for the current mode ──
    readonly property var results: {
        if (!open) return [];
        if (mode === "apps") return appResults();
        if (mode === "emoji") return emojiResults();
        if (mode === "clipboard") return clipResults();
        if (mode === "dmenu") return dmenuResults();
        // calc: one row
        return calcResult !== "" ? [{ title: calcResult, subtitle: term + "  =", calc: true }] : [];
    }
    onResultsChanged: if (selected >= results.length) selected = Math.max(0, results.length - 1)
    onTermChanged: { selected = 0; if (mode === "calc") calcDebounce.restart() }
    onModeChanged: { selected = 0; if (mode === "calc") calcDebounce.restart() }

    function activate(i) {
        const r = results[i];
        if (!r) return;
        if (mode === "dmenu") { answer(r.title); hide(); return; }
        hide();
        if (mode === "apps") {
            const e = r.entry;
            const cmd = e.runInTerminal ? ["kitty", "-e"].concat(e.command) : e.command;
            Quickshell.execDetached({ command: cmd, workingDirectory: e.workingDirectory || Quickshell.env("HOME") });
        } else if (mode === "calc") {
            Quickshell.execDetached(["wl-copy", "--", r.title]);
            Status.message("COPIED  " + r.title);
        } else if (mode === "emoji") {
            // copy, then type it once the launcher has given focus back
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy; sleep 0.15; wtype -- \"$1\"", "sh", r.glyph]);
        } else if (mode === "clipboard") {
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", r.line]);
        }
    }

    function removeClip(i) {
        const r = results[i];
        if (mode !== "clipboard" || !r) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", r.line]);
        clips = clips.filter(c => c.line !== r.line);
    }

    // ── Window ──
    PanelWindow {
        id: win

        screen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens) if (s.name === name) return s;
            return Quickshell.screens[0];
        }
        readonly property bool laptop: screen && screen.name.startsWith("eDP")
        readonly property int fontSize: laptop ? 14 : 12
        readonly property int rowHeight: Math.round(fontSize * 2.6)
        readonly property int maxRows: 8

        visible: root.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "horizon-launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: (laptop ? 32 : 28) + 4 + 10   // just above the bar island
        implicitWidth: Math.round(fontSize * 42)
        implicitHeight: panel.implicitHeight
        color: "transparent"

        HyprlandFocusGrab {
            windows: [win]
            active: win.visible
            onCleared: root.hide()
        }

        Rectangle {
            id: panel
            width: parent.width
            implicitHeight: body.implicitHeight + 16
            radius: 10
            color: Theme.alpha(Theme.surface, 0.95)
            border.color: Theme.border
            border.width: 1

            property real lift: 0
            transform: Translate { y: panel.lift }
            NumberAnimation { id: rise; target: panel; property: "lift"; from: 14; to: 0; duration: Theme.normal; easing.type: Easing.OutQuint }

            Column {
                id: body
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 6

                // Query line
                Item {
                    width: parent.width
                    height: win.rowHeight

                    Text {
                        id: prompt
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "calc" ? "=" : root.mode === "emoji" ? ":" : "❯"
                        font.family: Theme.font
                        font.pixelSize: win.fontSize + 1
                        color: Theme.accent
                    }

                    TextInput {
                        id: input
                        anchors.left: prompt.right
                        anchors.leftMargin: 10
                        anchors.right: chip.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        focus: root.open
                        onTextChanged: {
                            if (root.baseMode === "apps" && (text === "=" || text === ":" ||
                                    (text.length > 1 && (text[0] === "=" || text[0] === ":") && root.query === ""))) {
                                root.baseMode = text[0] === "=" ? "calc" : "emoji";
                                text = text.slice(1);
                                return;
                            }
                            root.query = text;
                        }
                        font.family: Theme.font
                        font.pixelSize: win.fontSize + 1
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        cursorDelegate: Rectangle { width: 2; color: Theme.fg; visible: input.cursorVisible }
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: root.mode === "apps" ? "search apps" : root.mode === "dmenu" ? "search" : root.mode === "calc" ? "expression"
                                : root.mode === "emoji" ? "search emoji" : "search clipboard"
                            font: input.font
                            color: Theme.dim
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) { root.hide(); event.accepted = true; }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(root.selected); event.accepted = true; }
                            else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J) || event.key === Qt.Key_Tab) {
                                root.selected = Math.min(root.results.length - 1, root.selected + 1); event.accepted = true;
                            }
                            else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K) || event.key === Qt.Key_Backtab) {
                                root.selected = Math.max(0, root.selected - 1); event.accepted = true;
                            }
                            else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) { root.removeClip(root.selected); event.accepted = true; }
                            else if (event.key === Qt.Key_Backspace && input.text === "" && root.baseMode !== "apps" && root.baseMode !== "dmenu") {
                                root.baseMode = "apps"; event.accepted = true;
                            }
                        }
                    }

                    Text {
                        id: chip
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "apps" ? "" : root.mode === "dmenu" ? root.dmenuPrompt.toUpperCase() : root.mode.toUpperCase()
                        font.family: Theme.font
                        font.pixelSize: win.fontSize * 0.8
                        font.letterSpacing: 1.2
                        color: Theme.dim
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.line }

                // Results
                ListView {
                    id: list
                    width: parent.width
                    height: Math.max(1, Math.min(root.results.length, win.maxRows)) * win.rowHeight
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === root.selected
                        width: list.width
                        height: win.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: row.isSelected ? Theme.raised : mouse.containsMouse ? Theme.hover : "transparent"
                        }
                        // the horizon line under the selected row
                        Rectangle {
                            visible: row.isSelected
                            x: 10
                            width: Math.min(parent.width * 0.3, 160)
                            anchors.bottom: parent.bottom
                            height: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
                                GradientStop { position: 0.5; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0) }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Item {
                                width: win.fontSize + 6
                                height: width
                                visible: root.mode === "apps" || root.mode === "emoji"
                                anchors.verticalCenter: parent.verticalCenter
                                // Muted (grey, dimmed) unless selected: colour only where attention is
                                IconImage {
                                    anchors.fill: parent
                                    visible: root.mode === "apps"
                                    source: root.mode === "apps" ? Quickshell.iconPath(row.modelData.icon || "", "application-x-executable") : ""
                                    asynchronous: true
                                    opacity: row.isSelected ? 1 : 0.7
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        saturation: row.isSelected ? 0 : -1
                                        brightness: row.isSelected ? 0 : -0.08
                                        Behavior on saturation { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuint } }
                                        Behavior on brightness { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuint } }
                                    }
                                    Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuint } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.mode === "emoji"
                                    text: row.modelData.glyph || ""
                                    font.pixelSize: win.fontSize + 4
                                }
                            }

                            Text {
                                id: title
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - (sub.visible ? sub.implicitWidth + 24 : 0) - win.fontSize * 2)
                                text: row.modelData.title
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: win.fontSize
                                color: row.isSelected ? Theme.fg : Theme.muted
                            }
                        }

                        Text {
                            id: sub
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== ""
                            width: Math.min(implicitWidth, parent.width * 0.4)
                            horizontalAlignment: Text.AlignRight
                            text: row.modelData.subtitle || ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: win.fontSize * 0.85
                            color: Theme.dim
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(row.index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.results.length === 0
                        text: root.mode === "calc" ? (root.term === "" ? "type an expression" : "…")
                            : root.mode === "clipboard" && root.clips.length === 0 ? "clipboard history is empty"
                            : "no matches"
                        font.family: Theme.font
                        font.pixelSize: win.fontSize * 0.9
                        color: Theme.dim
                    }
                }

                // Hints
                Row {
                    leftPadding: 10
                    topPadding: 2
                    spacing: win.fontSize * 1.4
                    Repeater {
                        model: root.mode === "dmenu" ? [["↵", "choose"], ["esc", "back"]]
                             : root.mode === "clipboard" ? [["↵", "copy"], ["⇧ del", "remove"], ["esc", "close"]]
                             : root.mode === "emoji" ? [["↵", "copy and type"], ["esc", "close"]]
                             : root.mode === "calc" ? [["↵", "copy result"], ["esc", "close"]]
                             : [["=", "calc"], [":", "emoji"], ["super v", "clipboard"], ["↵", "open"]]
                        Row {
                            required property var modelData
                            spacing: 6
                            Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: win.fontSize * 0.8; color: Theme.muted }
                            Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: win.fontSize * 0.8; color: Theme.dim }
                        }
                    }
                }
            }
        }
    }
}
