-- ── Key bindings ─────────────────────────────────────────────
-- Ported from ~/swaywm/sway/.config/sway/config (+ config.d).
-- Differences from Sway:
--   Super+W/S    tabbed/stacking → window group / next tab in the group
--   Super+B, Super+Shift+V  split → choose where the next window opens
--   Super+minus  scratchpad → special workspace "scratch"
--   Super+A      focus parent: dropped (Hyprland has no container tree)
--   Super+R      resize mode → Super+Ctrl+HJKL resizes directly
-- Menus, notifications and OSDs are Quickshell, called over `qs ipc`.

local mod     = "SUPER"
local term    = "kitty"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"
local exec    = hl.dsp.exec_cmd

local function key(k) return mod .. " + " .. k end
local function qs(target, fn, arg)
    return exec("qs ipc call " .. target .. " " .. fn .. (arg and (" " .. arg) or ""))
end

-- ── Basics ──
hl.bind(key("Return"),            exec(term))
hl.bind(key("q"),                 hl.dsp.window.close())
hl.bind(key("d"),                 qs("launcher", "toggle"))
hl.bind(key("x"),                 qs("power", "toggle"))
hl.bind(key("v"),                 qs("launcher", "open", "clipboard"))
hl.bind(key("CTRL + v"),          exec('cliphist wipe && notify-send -u low "Clipboard" "History cleared"'))
hl.bind(key("c"),                 qs("launcher", "open", "calc"))
hl.bind(key("period"),            qs("launcher", "open", "emoji"))
hl.bind(key("SHIFT + r"),         hl.dsp.reload_config())
hl.bind(key("SHIFT + Escape"),    exec("loginctl lock-session"))
hl.bind(key("SHIFT + e"),         hl.dsp.exit()) -- log out (the power menu, Super+X, asks first)

-- Drop-down terminal: kitty on the special workspace "dropdown"
-- (size and position come from the rule in rules.lua)
hl.bind(key("SHIFT + Return"), function()
    for _, w in ipairs(hl.get_windows() or {}) do
        if w.class == "dropdown" then
            hl.dispatch(hl.dsp.workspace.toggle_special("dropdown"))
            return
        end
    end
    hl.dispatch(exec("kitty --class dropdown"))
end)

-- Move/resize windows with Super + left/right mouse button
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- ── Focus and move: Super+HJKL / arrows ──
local dirs = { h = "left", j = "down", k = "up", l = "right",
               Left = "left", Down = "down", Up = "up", Right = "right" }
for k, dir in pairs(dirs) do
    hl.bind(key(k),           hl.dsp.focus({ direction = dir }))
    hl.bind(key("SHIFT + " .. k), hl.dsp.window.move({ direction = dir }))
end

-- ── Workspaces ──
-- Super+N goes there; Super+Shift+N sends the window and stays (as in Sway)
for i = 1, 10 do
    local k = tostring(i % 10)
    hl.bind(key(k),             hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. k), hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Jump to the other monitor / send the current workspace there
hl.bind(key("Tab"),         hl.dsp.focus({ monitor = "+1" }))
hl.bind(key("SHIFT + Tab"), hl.dsp.workspace.move({ monitor = "+1" }))

-- ── Layout ──
hl.bind(key("b"),           hl.dsp.layout("preselect r")) -- next window opens to the right
hl.bind(key("SHIFT + v"),   hl.dsp.layout("preselect d")) -- next window opens below
hl.bind(key("e"),           hl.dsp.layout("togglesplit"))
hl.bind(key("w"),           hl.dsp.group.toggle())        -- tabs (window group)
hl.bind(key("s"),           hl.dsp.group.next())          -- next tab in the group
hl.bind(key("f"),           hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(key("SHIFT + space"), hl.dsp.window.float({ action = "toggle" }))

-- Super+Space: move focus between tiled and floating windows
hl.bind(key("space"), function()
    local w = hl.get_active_window()
    if w and w.floating then
        hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
    end
end)

-- ── Scratchpad (special workspace) ──
hl.bind(key("minus"),         hl.dsp.workspace.toggle_special("scratch"))
hl.bind(key("SHIFT + minus"), hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- ── Resize: Super+Ctrl+HJKL / arrows (held keys repeat) ──
-- Replaces Sway's Super+R resize mode: Super = focus, +Shift = move, +Ctrl = resize.
-- H/L shrink/grow width, K/J shrink/grow height.
local step = 20
local resize = { h = { -step, 0 }, j = { 0, step }, k = { 0, -step }, l = { step, 0 },
                 Left = { -step, 0 }, Down = { 0, step }, Up = { 0, -step }, Right = { step, 0 } }
for k, s in pairs(resize) do
    hl.bind(key("CTRL + " .. k), hl.dsp.window.resize({ x = s[1], y = s[2], relative = true }), { repeating = true })
end

-- ── Volume, media (work on the lock screen too) ──
local vol = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "
hl.bind("XF86AudioRaiseVolume", exec(vol .. "5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec(vol .. "5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",     exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",        exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioStop",        exec("playerctl stop"),       { locked = true })
hl.bind("XF86AudioPause",       exec("playerctl pause"))
hl.bind("XF86AudioNext",        exec("playerctl next"))
hl.bind("XF86AudioPrev",        exec("playerctl previous"))
hl.bind("XF86AudioForward",     exec("playerctl position 10+"))
hl.bind("XF86AudioRewind",      exec("playerctl position 10-"))

-- ── Brightness: laptop panel or DDC monitor, whichever is focused ──
hl.bind(key("bracketleft"),    exec(scripts .. "brightness.sh down"), { repeating = true })
hl.bind(key("bracketright"),   exec(scripts .. "brightness.sh up"),   { repeating = true })
hl.bind("XF86MonBrightnessDown", exec(scripts .. "brightness.sh down"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   exec(scripts .. "brightness.sh up"),   { locked = true, repeating = true })

-- ── Screenshots and recording (saved to ~/Pictures/Screenshots and copied) ──
hl.bind("Print",         exec(scripts .. "screenshot.sh output"))
hl.bind("ALT + Print",   exec(scripts .. "screenshot.sh window"))
hl.bind("CTRL + Print",  exec(scripts .. "screenshot.sh area"))
hl.bind("SHIFT + Print", exec(scripts .. "record.sh"))

-- ── Tools ──
hl.bind(key("n"),               exec(scripts .. "nightlight.sh"))
hl.bind(key("grave"),           qs("notifications", "history"))
hl.bind(key("SHIFT + grave"),   qs("notifications", "clear"))
hl.bind(key("SHIFT + n"),       qs("notifications", "dnd"))
hl.bind(key("SHIFT + a"),       exec(scripts .. "appearance.sh")) -- GTK theme, dark/light, icons, cursor, font
