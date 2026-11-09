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

    // Motion: short, ease-out, one direction
    readonly property int fast: 160
    readonly property int normal: 260

    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/hypr/wallpaper.jpg"
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
