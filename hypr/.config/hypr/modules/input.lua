-- ── Input (same as Sway) ─────────────────────────────────────
-- Key repeat starts after 400 ms held, then 30 chars/s.
-- Caps Lock acts as Escape. Touchpad: tap to click, natural scrolling,
-- disabled while typing, two-finger scroll, middle-click emulation.

hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "caps:escape",
        repeat_delay = 400,
        repeat_rate  = 30,

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll          = true,
            tap_to_click            = true,
            disable_while_typing    = true,
            middle_button_emulation = true,
        },
    },
})

-- Three-finger swipe left/right switches workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
