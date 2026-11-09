-- ── Look: Horizon ────────────────────────────────────────────
-- Windows are opaque with 8px corners and a soft shadow. The focused
-- border runs from accent (top) to the photo's deep sky blue (bottom),
-- like the sky above the horizon. Unfocused borders blend into the dark.
-- Motion is short and one-directional: no bounce, no wobble.

local P = require("modules.palette")

local sky_gradient = { colors = { P.rgb("accent"), P.rgb("sky") }, angle = 90 }

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = sky_gradient,
            inactive_border = P.rgb("border"),
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 8,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_special = 0.35, -- darken the workspace behind the drop-down terminal

        shadow = {
            enabled        = true,
            range          = 24,
            render_power   = 3,
            offset         = "0 6",
            color          = P.rgba("bg", 0.70),
            color_inactive = P.rgba("bg", 0.40),
        },

        -- Only Quickshell panels are translucent (see rules.lua); windows stay opaque
        blur = {
            enabled  = true,
            size     = 6,
            passes   = 3,
            noise    = 0.02,
            vibrancy = 0.12,
            new_optimizations = true,
            popups   = false,
            special  = false,
        },
    },

    group = {
        col = {
            border_active          = sky_gradient,
            border_inactive        = P.rgb("border"),
            border_locked_active   = P.rgb("amber"),
            border_locked_inactive = P.rgb("border"),
        },
        groupbar = {
            enabled       = true,
            font_family   = "Maple Mono NF",
            font_size     = 11,
            height        = 18,
            indicator_height = 1,
            gradients     = true,
            rounding      = 4,
            gaps_in       = 4,
            gaps_out      = 4,
            render_titles = true,
            text_color          = P.rgb("fg"),
            text_color_inactive = P.rgb("muted"),
            col = {
                active          = P.rgb("raised"),
                inactive        = P.rgb("surface"),
                locked_active   = P.rgba("amber", 0.35),
                locked_inactive = P.rgb("surface"),
            },
        },
    },

    dwindle = {
        preserve_split = true,
        force_split    = 2, -- new windows open right/below, as in Sway
    },

    misc = {
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color        = P.rgb("ground"), -- shown until Quickshell draws the wallpaper
        font_family             = "Maple Mono NF",
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
        enable_swallow          = false,
        animate_manual_resizes  = false,
        -- If hyprlock ever crashes, a new one can take over the lock from a TTY:
        --   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
        allow_session_lock_restore = true,
    },

    binds = {
        workspace_back_and_forth = false, -- pressing the current workspace's key does nothing
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },

    cursor = {
        sync_gsettings_theme = true,
    },

    animations = { enabled = true },
})

-- ── Motion ───────────────────────────────────────────────────
-- speed is in tenths of a second: 2.5 = 250 ms
hl.curve("out",    { type = "bezier", points = { {0.22, 1}, {0.36, 1} } }) -- ease-out quint
hl.curve("inout",  { type = "bezier", points = { {0.65, 0}, {0.35, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0},    {1, 1}    } })

hl.animation({ leaf = "global",          enabled = true,  speed = 3,   bezier = "out" })
hl.animation({ leaf = "windowsIn",       enabled = true,  speed = 2.5, bezier = "out",    style = "popin 94%" })
hl.animation({ leaf = "windowsOut",      enabled = true,  speed = 1.6, bezier = "linear", style = "popin 94%" })
hl.animation({ leaf = "windowsMove",     enabled = true,  speed = 2.5, bezier = "out" })
hl.animation({ leaf = "fade",            enabled = true,  speed = 2,   bezier = "out" })
hl.animation({ leaf = "border",          enabled = true,  speed = 2,   bezier = "out" })
hl.animation({ leaf = "borderangle",     enabled = false })
hl.animation({ leaf = "layersIn",        enabled = true,  speed = 2.2, bezier = "out",    style = "fade" })
hl.animation({ leaf = "layersOut",       enabled = true,  speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",      enabled = true,  speed = 2.5, bezier = "out",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "out",    style = "slidevert" })
