-- ── Autostart ────────────────────────────────────────────────
-- Only this session's helpers. Sway's (waybar, dunst, kanshi, swayidle,
-- lxqt-policykit-agent) are never started here.
--
-- Quickshell starts first: it owns org.freedesktop.Notifications, so a
-- notification sent early can't D-Bus-activate dunst in this session.

--
-- Test run inside another session (a window in Sway):
--   HORIZON_NESTED=1 Hyprland
-- starts only Quickshell. Everything else here acts on the whole login
-- session (D-Bus env, polkit, idle → loginctl lock-session, tray applets)
-- and would interfere with the session it runs in.

local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"
local nested  = os.getenv("HORIZON_NESTED") == "1"

hl.on("hyprland.start", function()
    -- wallpaper, bar, launcher, notifications, OSDs. Restarted after a crash
    -- (e.g. Quickshell segfaulted once in QWindow::setScreen during a config
    -- reload); a clean exit (status 0) ends the loop.
    hl.exec_cmd("sh -c 'until qs; do sleep 1; done'")
    if nested then return end

    -- Share the session env with D-Bus/systemd, then start hyprland-session.target.
    -- It brings up graphical-session.target, which xdg-desktop-portal requires
    -- (file pickers, screen sharing). kanshi is kept out of it by the drop-in in
    -- ~/.config/systemd/user/kanshi.service.d/ (stow package `systemd`).
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
        .. " && systemctl --user start hyprland-session.target")
    -- polkit: Quickshell is the agent (Polkit.qml); it starts hyprpolkitagent
    -- itself if it can't register

    -- Night light follows the sun (scripts/nightlight.py); one instance only
    hl.exec_cmd(scripts .. "nightlight.py daemon")

    -- Idle: lock 5 min, screens off 10 min, suspend on battery 15 min
    hl.exec_cmd(scripts .. "keep-awake.sh start")

    -- Clipboard history (entries marked sensitive by password managers are skipped)
    hl.exec_cmd("wl-paste --watch cliphist -max-items 200 store")
    hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 200 store")

    -- Low-battery warnings (15% and 5%)
    hl.exec_cmd(scripts .. "battery-notify.sh")

    -- Tray applets (shown in the bar's tray drawer)
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
end)

-- Stop the session target on exit, so the next login (Sway or Hyprland) starts clean
hl.on("hyprland.shutdown", function()
    if not nested then hl.exec_cmd("systemctl --user stop hyprland-session.target") end
end)
