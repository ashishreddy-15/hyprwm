-- ── Window and layer rules ───────────────────────────────────

-- Never lock or blank the screen while anything is fullscreen (mpv, games, ...)
hl.window_rule({ name = "idle-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Ignore maximize requests: tiling decides window size
hl.window_rule({ name = "no-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- XWayland drag-and-drop helper windows must not take focus
hl.window_rule({
    name  = "xwayland-drag-fix",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Dialogs, file pickers and small utility windows float, centred
-- (class regexes; [.] is a literal dot)
local floating = {
    "^xdg-desktop-portal-gtk$",
    "^(org[.]pulseaudio[.])?pavucontrol(-qt)?$",
    "^nm-connection-editor$",
    "^[.]?blueman-manager.*$",
    "^(org[.]hyprland[.])?hyprpolkitagent$",
    "^qalculate-gtk$",
}
for i, class in ipairs(floating) do
    hl.window_rule({ name = "float-" .. i, match = { class = class }, float = true, center = true })
end
hl.window_rule({ name = "portal-size", match = { class = "^xdg-desktop-portal-gtk$" }, size = "900 600" })
hl.window_rule({ name = "float-dialog-title", match = { title = "^(Open File|Save File|Save As|Open Folder|File Upload).*$" }, float = true, center = true })
hl.window_rule({ name = "pip", match = { title = "^Picture.in.[Pp]icture$" }, float = true, pin = true, keep_aspect_ratio = true })

-- Drop-down terminal (Super+Shift+Return): floats centred on its own special workspace
hl.window_rule({
    name  = "dropdown",
    match = { class = "^dropdown$" },
    -- sizes are expressions in the Lua config ("80% 75%" is silently ignored)
    float = true, size = "monitor_w*0.8 monitor_h*0.75", center = true,
    workspace = "special:dropdown",
})

-- ── Quickshell panels: translucent with blur ──
-- Namespaces are set in ~/.config/quickshell (horizon-*)
hl.layer_rule({ name = "qs-blur",       match = { namespace = "^horizon-(bar|launcher|notifications|osd|power|calendar|powerpanel|notifcenter)$" }, blur = true, ignore_alpha = 0.2 })
-- Quickshell animates its own panels (springs); a second compositor fade on
-- top looks muddy, so Hyprland leaves these layers alone.
hl.layer_rule({ name = "qs-no-anim",    match = { namespace = "^horizon-(launcher|power|calendar|osd|notifications|powerpanel|overview|notifcenter|ambient)$" }, no_anim = true })
hl.layer_rule({ name = "qs-wallpaper",  match = { namespace = "^horizon-wallpaper$" }, no_anim = true })
