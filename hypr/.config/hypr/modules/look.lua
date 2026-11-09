-- ── Look: Horizon ────────────────────────────────────────────
-- Windows are opaque with 8px corners and a soft shadow. The focused
-- border runs from accent (top) to the photo's deep sky blue (bottom),
-- like the sky above the horizon. Unfocused borders blend into the dark.
-- Motion uses near-critically damped springs: physical, but no bounce or wobble.

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

-- ── Motion: Horizon springs ─────────────────────────────────
-- Tuned from a frame-by-frame screen recording (60 Hz panel):
--  * Light doesn't bounce: springs are damped close to critical (ζ ≈ 0.9),
--    ζ = damping / (2·√(stiffness·mass)).
--  * Nothing slides the full screen width. Any 1920 px move in ~0.3 s jumps
--    200–400 px per frame, which reads as a jerk, not motion. Workspaces
--    drift 20% and cross-fade instead (≤ ~50 px per frame), like light
--    changing at dusk.
--  * New windows fade in quickly so the bright horizon band doesn't flash
--    through behind them. Closing things just fade.
-- Quickshell's panels use the same physics (Theme.springs).
--
--   rise    k 600  ζ .90   new windows (popin), drop-down terminal
--   settle  k 450  ζ .92   windows moving / resizing to make room
--   glide   k 450  ζ .92   workspace drift (20% slide + fade, ~320 ms)
hl.curve("rise",   { type = "spring", mass = 1, stiffness = 600, damping = 44.1 })
hl.curve("settle", { type = "spring", mass = 1, stiffness = 450, damping = 39.0 })
hl.curve("glide",  { type = "spring", mass = 1, stiffness = 450, damping = 39.0 })

-- beziers for fades and exits; speed is in tenths of a second (1.2 = 120 ms)
hl.curve("out",    { type = "bezier", points = { {0.22, 1}, {0.36, 1} } }) -- ease-out quint
hl.curve("linear", { type = "bezier", points = { {0, 0},    {1, 1}    } })

hl.animation({ leaf = "global",           enabled = true,  speed = 3,   bezier = "out" })
hl.animation({ leaf = "windowsIn",        enabled = true,  speed = 4,   spring = "rise",   style = "popin 90%" })
hl.animation({ leaf = "windowsOut",       enabled = true,  speed = 1.2, bezier = "linear", style = "popin 94%" })
hl.animation({ leaf = "windowsMove",      enabled = true,  speed = 4,   spring = "settle" })
hl.animation({ leaf = "fadeIn",           enabled = true,  speed = 0.8, bezier = "out" }) -- fast, so the wallpaper doesn't flash through
hl.animation({ leaf = "fadeOut",          enabled = true,  speed = 1.2, bezier = "linear" })
hl.animation({ leaf = "fadeSwitch",       enabled = true,  speed = 2,   bezier = "out" })
hl.animation({ leaf = "border",           enabled = true,  speed = 2,   bezier = "out" })
hl.animation({ leaf = "borderangle",      enabled = false })
hl.animation({ leaf = "layersIn",         enabled = true,  speed = 2.2, bezier = "out",    style = "fade" })
hl.animation({ leaf = "layersOut",        enabled = true,  speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true,  speed = 4,   spring = "glide",  style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true,  speed = 4,   spring = "rise",   style = "slidefadevert 20%" })
