import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// One notification. The horizon line along the bottom shrinks until it
// closes; hovering pauses it. Critical ones stay until dismissed and use red.
// Left click: default action (if any) and dismiss. Right click: dismiss.
Rectangle {
    id: card

    required property var modelData            // Notification
    readonly property var notif: modelData
    signal timedOut()

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    // expireTimeout: -1/0 = server default / never; accept seconds or ms
    readonly property int timeout: {
        if (critical) return 0;
        const t = notif.expireTimeout;
        if (t > 0) return t < 100 ? t * 1000 : t;
        return 6000;
    }
    readonly property var actionList: notif.actions.filter(a => a.identifier !== "default")
    readonly property var defaultAction: notif.actions.find(a => a.identifier === "default") ?? null
    readonly property string imageSource: notif.image ? notif.image
        : (notif.appIcon && notif.appIcon.indexOf("/") === 0 ? "file://" + notif.appIcon : "")

    width: parent ? parent.width : 380
    implicitHeight: content.implicitHeight + 26
    radius: 8
    color: Theme.alpha(Theme.surface, Theme.popupAlpha)
    border.width: 1
    border.color: critical ? Theme.alpha(Theme.red, 0.6) : Theme.border
    clip: true

    // settles in from the right on a spring
    Spring { id: slideIn; preset: Theme.springs.settle; to: 0 }
    transform: Translate { x: slideIn.value }
    opacity: 1 - Math.min(1, slideIn.value / 10)
    Component.onCompleted: slideIn.from(10)   // stays inside the window padding

    Row {
        id: content
        x: 14
        y: 13
        width: card.width - 28
        spacing: 12

        Image {
            id: thumb
            visible: card.imageSource !== "" && status === Image.Ready
            source: card.imageSource
            width: 44
            height: 44
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 88
            sourceSize.height: 88
            asynchronous: true
        }

        Column {
            width: content.width - (thumb.visible ? thumb.width + content.spacing : 0)
            spacing: 3

            Text {
                width: parent.width
                text: (card.notif.appName || "notification").toUpperCase()
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 11
                font.letterSpacing: 0.8
                color: card.critical ? Theme.red : Theme.dim
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: card.notif.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.fg
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: card.notif.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.muted
                linkColor: Theme.accent
            }

            Row {
                visible: card.actionList.length > 0
                spacing: 8
                topPadding: 6
                Repeater {
                    model: card.actionList
                    Rectangle {
                        required property var modelData
                        width: actionText.implicitWidth + 20
                        height: actionText.implicitHeight + 8
                        radius: 4
                        color: actionMouse.containsMouse ? Theme.hover : Theme.raised
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.fg
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { parent.modelData.invoke(); card.notif.dismiss() }
                        }
                    }
                }
            }
        }
    }

    // Click / hover handling under the action buttons
    MouseArea {
        id: hover
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke();
            card.notif.dismiss();
        }
    }

    // Remaining time: the horizon line shrinks toward the left
    Rectangle {
        id: timer
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        x: 1
        height: 1
        width: card.timeout > 0 ? (card.width - 2) * progress : card.width - 2
        property real progress: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(card.critical ? Theme.red : Theme.accent, 0) }
            GradientStop { position: 0.5; color: card.critical ? Theme.red : Theme.accent }
            GradientStop { position: 1.0; color: Theme.alpha(card.critical ? Theme.red : Theme.accent, 0) }
        }

        NumberAnimation on progress {
            from: 1; to: 0
            duration: Math.max(1, card.timeout)
            running: card.timeout > 0
            paused: running && hover.containsMouse
            onFinished: card.timedOut()
        }
    }
}
