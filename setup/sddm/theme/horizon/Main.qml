// horizon: SDDM login theme matching the Horizon lock screen (hyprlock.conf)
// and the bar island. Palette lives in theme.conf, exposed here as config.*
//
//   the dusk wallpaper, full-bleed
//   the clock in the empty sky above the mountain, the date spaced below it
//   the password on the dark ground: dots over a thin glowing horizon line
//     (red after a wrong password; "caps lock is on" in amber)
//   a small island at the bottom, like the bar: session · suspend reboot shutdown
//
// Keys (password field): Enter log in · Esc clear · Up/Down switch user
//                        Tab moves to the session and power buttons
//
// Test without logging out:   ~/hyprwm/setup/sddm.sh --test

import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1200
    color: config.ground

    // Fonts are copied here by setup/sddm.sh; the sddm user can't read ~/.local.
    FontLoader { source: "fonts/MapleMono-NF-ExtraLight.ttf" }
    FontLoader { source: "fonts/MapleMono-NF-Regular.ttf" }
    FontLoader { source: "fonts/MapleMono-NF-Medium.ttf" }

    // Sizes follow the screen height (the lock screen was laid out on 1200 px)
    readonly property real u: height / 1200

    // ── State ─────────────────────────────────────────────────
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool capsOn: typeof keyboard !== "undefined" && keyboard.capsLock

    readonly property var user: users.count > 0 ? users.itemAt(userIndex) : null
    readonly property string userName: user ? user.name : userModel.lastUser
    readonly property var session: sessions.count > 0 ? sessions.itemAt(sessionIndex) : null

    // Models are only reachable through delegates, so keep hidden copies.
    Item {
        visible: false
        Repeater {
            id: users
            model: userModel
            delegate: Item {
                required property string name
                required property string realName
            }
        }
        Repeater {
            id: sessions
            model: sessionModel
            delegate: Item {
                required property string name
            }
        }
    }

    function login() {
        if (busy || userName === "")
            return
        busy = true
        failed = false
        message = ""
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy = false
            failed = true
            message = "wrong password"
            password.text = ""
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { message = "" }
        function onInformationMessage(msg) { message = msg }
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ── Wallpaper (every screen) ──────────────────────────────
    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        // fade in from the ground colour
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    // Click anywhere to get back to the password field.
    MouseArea {
        anchors.fill: parent
        onClicked: password.forceActiveFocus()
    }

    // SDDM opens one window per screen. The form goes on the largest screen
    // (the Samsung when docked); the others show just the wallpaper.
    // (sddm.sh --test sets forceMain, since a preview is one window on any screen)
    readonly property bool mainScreen: {
        if (config.forceMain === "true") return true
        let largest = 0
        for (const s of Qt.application.screens)
            largest = Math.max(largest, s.width * s.height)
        return largest === 0 || width * height >= largest
    }

    Item {
        id: content
        anchors.fill: parent
        visible: root.mainScreen
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Component.onCompleted: opacity = 1

        // ── Clock, in the sky ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.11)
            text: Qt.formatTime(root.now, config.clockFormat)
            color: config.fg
            font.family: config.font
            font.weight: Font.ExtraLight
            font.pixelSize: Math.round(150 * root.u)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.29)
            text: Qt.formatDate(root.now, config.dateFormat).toUpperCase()
            color: config.muted
            font.family: config.font
            font.pixelSize: Math.round(14 * root.u)
            font.letterSpacing: 4 * root.u
        }

        // ── Password, on the ground below the horizon ──
        Column {
            id: form
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.66)
            spacing: Math.round(10 * root.u)

            // User: plain text; arrows only when there is a choice
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.user && root.user.realName !== "" ? root.user.realName : root.userName)
                      + (users.count > 1 ? "  ↑↓" : "")
                color: config.dim
                font.family: config.font
                font.pixelSize: Math.round(13 * root.u)
                font.letterSpacing: 1
            }

            Item {
                id: field
                width: Math.round(340 * root.u)
                height: Math.round(40 * root.u)

                TextInput {
                    id: password
                    anchors.fill: parent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    activeFocusOnTab: true
                    clip: true
                    readOnly: root.busy
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    color: config.fg
                    selectionColor: config.raised
                    selectedTextColor: config.fg
                    font.family: config.font
                    font.pixelSize: Math.round(18 * root.u)
                    font.letterSpacing: 6 * root.u
                    // cursor only once typing starts: centred, it would cut through "type to unlock"
                    cursorDelegate: Rectangle { width: 2; color: config.accent; visible: password.cursorVisible && password.text !== "" }

                    onAccepted: root.login()
                    onTextEdited: { root.failed = false; root.message = "" }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            text = ""
                            root.failed = false
                            root.message = ""
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                            if (users.count > 1) {
                                const step = event.key === Qt.Key_Down ? 1 : -1
                                root.userIndex = (root.userIndex + step + users.count) % users.count
                                text = ""
                            }
                            event.accepted = true
                        } else if (event.text.length === 1) {
                            // Wayland gives no Caps Lock state; infer it from letter case vs Shift.
                            const ch = event.text
                            if (ch.toUpperCase() !== ch.toLowerCase()) {
                                const shift = (event.modifiers & Qt.ShiftModifier) !== 0
                                root.capsOn = (ch === ch.toUpperCase()) !== shift
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "logging in…" : "type to unlock"
                    color: config.dim
                    font.family: config.font
                    font.pixelSize: Math.round(13 * root.u)
                    visible: password.text === ""
                }
            }

            // The horizon line: soft glow, brighter while typing, red on failure
            Item {
                id: hline
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width
                height: 5
                readonly property color tone: root.failed ? config.red : config.accent
                opacity: root.failed || password.text !== "" ? 1 : password.activeFocus ? 0.75 : 0.4
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Rectangle {   // halo
                    anchors.fill: parent
                    radius: 2.5
                    opacity: 0.25
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: hline.tone }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {   // core
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: hline.tone }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // Status line; fixed height so nothing jumps
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.round(16 * root.u)
                text: root.failed ? root.message
                    : root.capsOn ? "CAPS LOCK"
                    : root.message
                color: root.failed ? config.red : root.capsOn ? config.amber : config.muted
                font.family: config.font
                font.pixelSize: Math.round(11 * root.u)
                font.letterSpacing: 1.5
            }
        }

        // ── Island at the bottom, like the bar ──
        Rectangle {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: Math.round(Math.min(parent.width * 0.5, 1040))
            height: Math.round(32 * root.u)
            radius: 8
            color: Qt.rgba(0.086, 0.102, 0.078, 0.88)   // surface
            border.width: 1
            border.color: config.border

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 6
                height: parent.height

                TextButton {
                    visible: sessions.count > 0
                    text: root.session ? root.session.name.toLowerCase() + (sessions.count > 1 ? "  ‹›" : "") : ""
                    onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                height: parent.height

                TextButton { text: "suspend";  enabled: sddm.canSuspend;  onClicked: sddm.suspend() }
                TextButton { text: "reboot";   enabled: sddm.canReboot;   onClicked: sddm.reboot() }
                TextButton { text: "shut down"; enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
            }
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
