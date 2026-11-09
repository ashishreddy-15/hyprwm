import QtQuick
import Quickshell
import Quickshell.Hyprland

// Keys handled inside Quickshell through Hyprland's global-shortcuts protocol.
// Bound in ~/.config/hypr/modules/binds.lua as hl.dsp.global("quickshell:<name>").
// Unlike `qs ipc call ...`, no process is started per key press, so panels
// open on the next frame. (The `qs ipc` targets remain for scripts.)
Scope {
    id: root
    required property var launcher
    required property var power
    required property var notifications

    GlobalShortcut { name: "launcher";      description: "Launcher: apps";             onPressed: root.launcher.toggle() }
    GlobalShortcut { name: "clipboard";     description: "Launcher: clipboard history"; onPressed: root.launcher.toggleMode("clipboard") }
    GlobalShortcut { name: "calc";          description: "Launcher: calculator";       onPressed: root.launcher.toggleMode("calc") }
    GlobalShortcut { name: "emoji";         description: "Launcher: emoji";            onPressed: root.launcher.toggleMode("emoji") }
    GlobalShortcut { name: "power";         description: "Power menu";                 onPressed: root.power.toggle() }
    GlobalShortcut { name: "notif-history"; description: "Show the last notification"; onPressed: root.notifications.historyPop() }
    GlobalShortcut { name: "notif-clear";   description: "Dismiss all notifications";  onPressed: root.notifications.clearAll() }
    GlobalShortcut { name: "dnd";           description: "Do not disturb on/off";      onPressed: Status.toggleDnd() }
}
