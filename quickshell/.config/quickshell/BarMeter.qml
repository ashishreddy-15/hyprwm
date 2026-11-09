import QtQuick

// LABEL ━━━━── 62
// A thin track. The sky → accent gradient spans the whole track and the fill
// reveals it, so the colour itself says the level: low shows only deep sky,
// only high reaches the bright accent (like the sky lightening toward the
// horizon). `tone` overrides it for warnings (amber) and critical (red).
//
// sweep(): one pass of light along the track (e.g. charger plugged in);
// `lit`: a soft static glow under the fill (e.g. while charging).
Item {
    id: root

    property string label: ""
    property real fraction: 0          // 0..1
    property int value: 0
    property int fontSize: 13
    property color tone: "transparent" // transparent = normal gradient
    property bool dimmed: false        // e.g. muted
    property bool lit: false

    readonly property bool toned: tone.a > 0

    signal clicked()
    signal scrolled(int steps)

    // reverse = light running back (e.g. unplugged)
    function sweep(reverse) {
        sweepLight.reverse = reverse === true;
        sweepAnim.restart();
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: dimmed ? 0.5 : 1

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.fontSize * 0.5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.font
            font.pixelSize: root.fontSize * 0.86
            color: Theme.muted
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.fontSize * 3.2)
            height: 2
            radius: 1
            color: Theme.border

            Spring { id: fillW; preset: Theme.springs.settle; to: Math.max(0, Math.min(1, root.fraction)) * track.width }

            // static glow under the fill while `lit`
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: fillW.value
                height: 6
                radius: 3
                color: root.toned ? root.tone : Theme.accent
                opacity: root.lit ? 0.18 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }

            // the fill reveals a gradient as wide as the track
            Item {
                width: fillW.value
                height: parent.height
                clip: true
                Rectangle {
                    width: track.width
                    height: parent.height
                    radius: 1
                    color: root.tone
                    gradient: root.toned ? null : levelGradient
                }
            }

            Gradient {
                id: levelGradient
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.sky }
                GradientStop { position: 1.0; color: Theme.accent }
            }

            // one pass of light along the track
            Item {
                anchors.fill: parent
                clip: true
                Rectangle {
                    id: sweepLight
                    property bool reverse: false
                    property real p: 0          // 0..1 progress
                    anchors.verticalCenter: parent.verticalCenter
                    width: track.width * 0.45
                    height: 2
                    x: (reverse ? 1 - p : p) * (track.width + width) - width
                    opacity: p > 0 && p < 1 ? 1 : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.fg, 0) }
                        GradientStop { position: 0.5; color: sweepLight.reverse ? Theme.alpha(Theme.muted, 0.8) : Theme.fg }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.fg, 0) }
                    }
                }
                NumberAnimation {
                    id: sweepAnim
                    target: sweepLight
                    property: "p"
                    from: 0; to: 1
                    duration: 800
                    easing.type: Easing.InOutCubic
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            font.family: Theme.font
            font.pixelSize: root.fontSize
            color: root.toned ? root.tone : Theme.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
