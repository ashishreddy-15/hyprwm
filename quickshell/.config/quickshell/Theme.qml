pragma Singleton

import QtQuick
import Quickshell

// Horizon palette: the same tokens as ~/swaywm/colors.md, plus `sky`.
// Rules: accent = focus only; amber = a mode is on / warning; red = act now.
Singleton {
    readonly property color bg:      "#0f110d"
    readonly property color ground:  "#13160f"
    readonly property color surface: "#161a14"
    readonly property color hover:   "#20251d"
    readonly property color raised:  "#222820"
    readonly property color line:    "#232820"
    readonly property color border:  "#2e342a"
    readonly property color dim:     "#5a6152"
    readonly property color muted:   "#8c9384"
    readonly property color fg:      "#e6e8e1"
    readonly property color accent:  "#6fa3b8"
    readonly property color sky:     "#06587a"
    readonly property color amber:   "#db892d"
    readonly property color red:     "#e05555"

    // Panels are slightly translucent (Hyprland blurs behind them)
    readonly property real panelAlpha: 0.88

    readonly property string font: "Maple Mono NF"

    // Motion: fades use these durations; movement uses springs (Spring.qml)
    readonly property int fast: 160
    readonly property int normal: 260

    // Horizon springs, tuned from a frame-by-frame screen recording.
    // Light doesn't bounce: damping ratio ζ = d / (2·√(k·m)) ≈ 0.9–0.95.
    // Small moves (a 20 px panel rise) need softer springs than big ones, or
    // they finish in 2–3 frames and read as a pop instead of motion.
    readonly property var springs: ({
        rise:   { stiffness: 300, damping: 31.2, mass: 1 },  // panels rising 20 px out of the bar (~8 frames)
        settle: { stiffness: 450, damping: 39.0, mass: 1 },  // meters, notifications, numbers making room
        glide:  { stiffness: 350, damping: 35.5, mass: 1 },  // the workspace underline (~12 frames)
        drift:  { stiffness: 200, damping: 26.9, mass: 1 }   // the edge glow, trailing the underline like light
    })

    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/hypr/wallpaper.jpg"
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
