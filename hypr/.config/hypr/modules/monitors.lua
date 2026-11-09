-- ── Monitors ─────────────────────────────────────────────────
-- Physical layout (same as Sway / kanshi):
--   [laptop eDP-1] [Samsung 27"]
--   eDP-1    x=0..1920,    y=240..1440  (bottom-aligned with the Samsung)
--   Samsung  x=1920..4480, y=0..1440    @100Hz
-- The Samsung is matched by make/model/serial, so it works on HDMI or USB-C.
-- Any other external screen goes to the right at its preferred mode.
--
-- Hyprland handles hotplug itself, so kanshi is not used here (it only
-- runs in the Sway session, via graphical-session.target).
--
-- Workspaces: 1-5 prefer the Samsung, 6-10 prefer the laptop, each falling
-- back to the other screen. When a screen comes back, its workspaces move
-- back to it (Sway did this with `workspace N output A B`).
--
-- Lid: closing it turns the laptop panel off, but only while another screen
-- is connected; otherwise logind handles the lid (suspend) as usual.

local LAPTOP  = "eDP-1"
local SAMSUNG = "Samsung Electric Company LS27F61x H4CL500159"

local function laptop_rule(disabled)
    hl.monitor({ output = LAPTOP, disabled = disabled, mode = "1920x1200", position = "0x240", scale = 1 })
end

hl.monitor({ output = "desc:" .. SAMSUNG, mode = "2560x1440@100", position = "1920x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = 1 })

-- ── Helpers ──
local function lid_closed()
    local p = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
    if not p then return false end
    local s = p:read("*a") or ""
    p:close()
    return s:find("closed") ~= nil
end

local function find_monitor(pred)
    for _, m in ipairs(hl.get_monitors() or {}) do
        if pred(m) then return m end
    end
end

local function samsung() return find_monitor(function(m) return (m.description or ""):find(SAMSUNG, 1, true) ~= nil end) end
local function laptop()  return find_monitor(function(m) return m.name == LAPTOP end) end
local function has_external() return find_monitor(function(m) return m.name ~= LAPTOP end) ~= nil end

-- Laptop panel on/off from the lid state. `closed` overrides the ACPI read
-- (the lid switch binding knows the new state before /proc does).
local function apply_lid(closed)
    if closed == nil then closed = lid_closed() end
    laptop_rule(closed and has_external())
end

-- Move workspaces 1-10 to their preferred screen if it is connected.
local function rehome_workspaces()
    local s, l = samsung(), laptop()
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local id = ws.id
        if id and id >= 1 and id <= 10 and not ws.special then
            local target
            if id <= 5 then target = s or l else target = l or s end
            if target and ws.monitor and ws.monitor.name ~= target.name then
                hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = target.name }))
            end
        end
    end
end

for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = (i <= 5) and ("desc:" .. SAMSUNG) or LAPTOP })
end

-- Initial state (also re-evaluated on every config reload)
apply_lid()

-- Let a new screen finish its modeset before moving things onto it
local function settle(fn) hl.timer(fn, { timeout = 600, type = "oneshot" }) end

hl.on("monitor.added",   function() settle(function() apply_lid(); rehome_workspaces() end) end)
hl.on("monitor.removed", function() settle(function() apply_lid() end) end)

hl.bind("switch:on:Lid Switch",  function() apply_lid(true) end,  { locked = true })
hl.bind("switch:off:Lid Switch", function() apply_lid(false); settle(rehome_workspaces) end, { locked = true })
