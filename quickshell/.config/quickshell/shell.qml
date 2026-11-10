//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import Quickshell.Io

// Horizon shell for the Hyprland session (started by autostart.lua).
// Quickshell reloads this on save; `qs log` shows errors.
//
// Built: wallpaper, bar (glow island), notifications, OSD, launcher, power menu,
// overview, ambient screen, lock screen, polkit agent.
// Icons: Papirus-Dark for Quickshell only (GTK/Sway keep their own theme).
// `qs ipc` targets (launcher, power, notifications, osd, shell) are bound in ~/.config/hypr/modules/binds.lua.
ShellRoot {
    // `qs ipc call shell reload` — edits to the stowed (symlinked) files are
    // not always picked up by Quickshell's file watcher, so reload explicitly.
    IpcHandler {
        target: "shell"
        // never while locked: a reload is the risky moment for the lock screen
        function reload(): void { if (!lock.locked) Quickshell.reload(true) }
    }

    Wallpaper {}
    Bar {}
    Notifications { id: notifications }
    Osd {}
    Launcher { id: launcher }
    PowerMenu { id: power }
    Overview { id: overview }
    Ambient {}
    Lock { id: lock }
    Polkit {}
    Shortcuts { launcher: launcher; power: power; notifications: notifications; overview: overview }
}
