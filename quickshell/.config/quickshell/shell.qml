//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import Quickshell.Io

// Horizon shell for the Hyprland session (started by autostart.lua).
// Quickshell reloads this on save; `qs log` shows errors.
//
// Built: wallpaper, bar (glow island), notifications, OSD, launcher, power menu.
// Icons: Papirus-Dark for Quickshell only (GTK/Sway keep their own theme).
// `qs ipc` targets (launcher, power, notifications, osd, shell) are bound in ~/.config/hypr/modules/binds.lua.
ShellRoot {
    // `qs ipc call shell reload` — edits to the stowed (symlinked) files are
    // not always picked up by Quickshell's file watcher, so reload explicitly.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(true) }
    }

    Wallpaper {}
    Bar {}
    Notifications { id: notifications }
    Osd {}
    Launcher { id: launcher }
    PowerMenu { id: power }
    Shortcuts { launcher: launcher; power: power; notifications: notifications }
}
