-- ── Wacom Intuos (BT S) ──────────────────────────────────────
-- The pen is mapped to ONE screen instead of spanning both: the Samsung
-- when it is connected, otherwise the laptop panel. The tablet surface is
-- 152x95 mm (16:10); the Samsung is 16:9, so the pen area is cropped
-- (full width, centered vertically) to keep 1 mm of pen = the same distance
-- horizontally and vertically. The laptop panel is 16:10 and uses the whole
-- surface. Applied to every tablet, so USB and Bluetooth behave the same.

local TABLET_W, TABLET_H = 152, 95
local LAPTOP  = "eDP-1"

local function apply_tablet()
    local target
    for _, m in ipairs(hl.get_monitors() or {}) do
        if m.name ~= LAPTOP then target = m; break end
    end
    if not target then
        for _, m in ipairs(hl.get_monitors() or {}) do
            if m.name == LAPTOP then target = m; break end
        end
    end
    if not target then return end

    local w, h = target.width or 16, target.height or 10
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

hl.on("monitor.added",   function() hl.timer(apply_tablet, { timeout = 800, type = "oneshot" }) end)
hl.on("monitor.removed", function() hl.timer(apply_tablet, { timeout = 800, type = "oneshot" }) end)
