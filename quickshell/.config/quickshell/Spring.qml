import QtQuick

// A damped spring, integrated every frame with the same physics as
// Hyprland's spring curves (stiffness, damping, mass): one set of springs
// for windows and panels alike. Presets live in Theme.springs.
//
//   Spring { id: s; preset: Theme.springs.glide; to: target }   x: s.value
//   s.from(18)    start from 18 and spring to `to` (e.g. a panel rising)
//
// Horizon rule: damping ratio ≈ 0.95, so motion settles without overshoot.
Item {
    id: s
    visible: false

    property var preset: Theme.springs.settle
    property real stiffness: preset.stiffness
    property real damping: preset.damping
    property real mass: preset.mass

    property real to: 0
    property real value: 0
    property real velocity: 0
    readonly property bool moving: frames.running

    property bool _ready: false
    property bool _skip: false   // the first frame after a start can be slow; don't let it eat the motion
    // (from() may already have been called by a parent's onCompleted; keep that motion)
    Component.onCompleted: { if (!frames.running) value = to; _ready = true }
    onToChanged: if (_ready) frames.running = true

    // Jump to `start` and spring towards `to`
    function from(start) { value = start; velocity = 0; _skip = true; frames.running = true }
    // Snap without animating
    function snap() { value = to; velocity = 0; frames.running = false }

    FrameAnimation {
        id: frames
        onTriggered: {
            if (s._skip) { s._skip = false; return; }
            // fixed small sub-steps keep the integration stable on slow frames
            const dt = Math.min(frameTime, 0.05);
            const steps = Math.max(1, Math.ceil(dt / 0.004));
            const h = dt / steps;
            let x = s.value, v = s.velocity;
            for (let i = 0; i < steps; i++) {
                const a = (-s.stiffness * (x - s.to) - s.damping * v) / s.mass;
                v += a * h;
                x += v * h;
            }
            if (Math.abs(x - s.to) < 0.02 && Math.abs(v) < 0.5) { x = s.to; v = 0; running = false; }
            s.velocity = v;
            s.value = x;
        }
    }
}
