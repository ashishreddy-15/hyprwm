-- ============================================================
-- Hyprland (Lua config, 0.57+) — "Horizon"
--
-- Runs next to the Sway setup in ~/swaywm: same palette, same keys,
-- separate daemons. Quickshell draws the wallpaper, bar, launcher,
-- notifications and OSDs; kitty is the terminal.
--
-- Check a change without reloading:  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Hyprland reloads this file on save; Super+Shift+R also reloads.
-- ============================================================

require("modules.env")
require("modules.monitors")
require("modules.look")
require("modules.input")
require("modules.binds")
require("modules.rules")
require("modules.autostart")
