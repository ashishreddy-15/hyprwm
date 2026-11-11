-- ── Wacom Intuos (BT S) ──────────────────────────────────────
-- The pen is mapped to ONE screen instead of spanning both, and it follows
-- your notes:
--   1. the monitor Obsidian is on (move Obsidian to the other screen and the
--      pen goes with it), else
--   2. the external screen (the Samsung), else
--   3. the laptop panel.
--
-- The tablet surface is 152x95 mm (16:10). The laptop panel is 16:10 and uses
-- the whole surface; a 16:9 screen like the Samsung gets the area cropped
-- (full width, centered vertically), so 1 mm of pen is the same distance
-- horizontally and vertically (no stretched handwriting).
-- Applied to every tablet, so USB and Bluetooth behave the same.
--
-- To follow a different app, change NOTES_CLASS (a Lua pattern, matched
-- case-insensitively against the window class; the Flatpak reports
-- "md.obsidian.Obsidian").

local TABLET_W, TABLET_H = 152, 95
local LAPTOP      = "eDP-1"
local NOTES_CLASS = "obsidian"

local function monitor_by(pred)
    for _, m in ipairs(hl.get_monitors() or {}) do
        if pred(m) then return m end
    end
end

-- The monitor the notes app is on, or nil.
local function notes_monitor()
    if not hl.get_windows then return nil end
    for _, w in ipairs(hl.get_windows() or {}) do
        local class = (w.class or ""):lower()
        if class:find(NOTES_CLASS, 1, true) and w.mapped ~= false and w.monitor then
            return monitor_by(function(m) return m.name == w.monitor.name end)
        end
    end
end

local last
local function apply_tablet()
    local target = notes_monitor()
        or monitor_by(function(m) return m.name ~= LAPTOP end)
        or monitor_by(function(m) return m.name == LAPTOP end)
    if not target then return end

    local w, h = target.width or 16, target.height or 10
    local key = target.name .. w .. "x" .. h
    if key == last then return end
    last = key

    local area_h = math.min(TABLET_H, TABLET_W * h / w)
    local area_w = math.min(TABLET_W, TABLET_H * w / h)

    hl.config({
        input = {
            tablet = {
                output               = target.name,
                active_area_size     = { area_w, area_h },
                active_area_position = { (TABLET_W - area_w) / 2, (TABLET_H - area_h) / 2 },
            },
        },
    })
end

apply_tablet()

-- Let windows/monitors settle before looking (a window is moved, then mapped)
local function settle() hl.timer(apply_tablet, { timeout = 400, type = "oneshot" }) end

hl.on("monitor.added",   function() last = nil; settle() end)
hl.on("monitor.removed", function() last = nil; settle() end)
hl.on("window.open",              settle)
hl.on("window.close",             settle)
hl.on("window.move_to_workspace", settle)
