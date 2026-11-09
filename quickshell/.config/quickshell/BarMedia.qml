import QtQuick
import Quickshell.Services.Mpris

// "Title · Artist" with three small level bars, only while something plays.
// The parent sets `width`; the text shortens with … and the whole item
// hides when there's no room, so it never reaches the clock.
Item {
    id: root

    property int fontSize: 13
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i];
        return null;
    }
    readonly property string track: !player ? ""
        : (player.trackTitle || player.identity || "") + (player.trackArtist ? "  ·  " + player.trackArtist : "")

    implicitWidth: eq.width + 8 + title.implicitWidth
    implicitHeight: fontSize * 1.4
    visible: player !== null && width >= fontSize * 6
    clip: true

    Row {
        id: eq
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        height: root.fontSize * 0.75
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 2
                radius: 1
                color: Theme.accent
                height: parent.height * 0.3
                SequentialAnimation on height {
                    running: root.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 180 }
                    NumberAnimation { to: eq.height;       duration: 520; easing.type: Easing.InOutSine }
                    NumberAnimation { to: eq.height * 0.3; duration: 520; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Text {
        id: title
        anchors.left: eq.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.track
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: root.fontSize
        color: Theme.muted
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.player) root.player.togglePlaying()
    }
}
