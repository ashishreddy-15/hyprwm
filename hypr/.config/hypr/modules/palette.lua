-- Palette: the same tokens as ~/swaywm/colors.md (taken from the wallpaper),
-- plus `sky`, the photo's deep blue, used only as the far end of gradients.
-- Rules: accent = focus only; amber = a mode is on / warning; red = act now.

local P = {
    bg      = "0f110d", -- terminal, editor, lock screen
    ground  = "13160f", -- the wallpaper's own black (fallback colour)
    surface = "161a14", -- bar, launcher, notifications
    hover   = "20251d",
    raised  = "222820", -- selections, inactive buttons
    line    = "232820", -- separators inside a surface
    border  = "2e342a", -- unfocused windows, panel edges
    dim     = "5a6152", -- inactive text
    muted   = "8c9384", -- labels, secondary text
    fg      = "e6e8e1", -- primary text
    accent  = "6fa3b8", -- focus
    sky     = "06587a", -- gradient end (new in Hyprland)
    amber   = "db892d", -- something is on
    red     = "e05555", -- needs attention now
}

-- "rgb(6fa3b8)" / "rgba(6fa3b8cc)" strings for Hyprland options
function P.rgb(name) return "rgb(" .. P[name] .. ")" end
function P.rgba(name, alpha) return string.format("rgba(%s%02x)", P[name], math.floor(alpha * 255 + 0.5)) end

return P
