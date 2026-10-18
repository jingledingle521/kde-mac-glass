import QtQuick
import QtQuick.Controls.Basic as QQC2
import Qt5Compat.GraphicalEffects

// macOS-style login screen for SDDM, matching the Golden Gate lock screen:
// date and a large frosted clock at the top, the user's avatar and a pill
// password field near the bottom, and Sleep / Restart / Shut Down below.
// Uses only plain Qt Quick so it doesn't depend on Plasma libraries.
Rectangle {
    id: ui

    // Sizes are designed for a 1707x1067 logical screen and scale from there.
    readonly property real s: Math.max(0.6, Math.min(width / 1707, height / 1067))
    readonly property string font: inter.status === FontLoader.Ready ? inter.font.family : "sans-serif"
    readonly property color glass: Qt.rgba(1, 1, 1, 0.22)
    property var now: new Date()
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string message: ""
    property bool busy: false

    // The selected user's delegate (see userRepeater). Depends on count so it
    // updates once the user list has loaded.
    readonly property Item currentUser: userRepeater.count > 0 ? userRepeater.itemAt(Math.min(userIndex, userRepeater.count - 1)) : null

    function userRole(role) {
        return currentUser ? currentUser[role] : "";
    }

    function login() {
        if (busy) {
            return;
        }
        busy = true;
        message = "";
        sddm.login(userRole("userName"), passwordField.text, sessionIndex);
    }

    color: "black"

    FontLoader {
        id: inter
        source: "fonts/Inter.ttf"
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            ui.busy = false;
            ui.message = "Incorrect password";
            passwordField.selectAll();
            passwordField.forceActiveFocus();
            shake.restart();
        }
        function onLoginSucceeded() {
            ui.message = "";
        }
        function onInformationMessage(message) {
            ui.message = message;
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ui.now = new Date()
    }

    // Users are read through invisible delegates so roles can be looked up by index.
    Repeater {
        id: userRepeater
        model: userModel
        // Roles are read through `model` so a role missing in some SDDM
        // version can't break the delegate.
        delegate: Item {
            readonly property string userName: model.name || ""
            readonly property string displayName: model.realName ? model.realName : (model.name || "")
            readonly property string avatar: model.icon || ""
            readonly property bool passwordNeeded: model.needsPassword !== false
        }
    }

    Image {
        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    // Soft darkening at the top and bottom keeps white text legible.
    LinearGradient {
        anchors.fill: parent
        start: Qt.point(0, 0)
        end: Qt.point(0, height)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.32) }
        }
    }

    // ---- Clock -----------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.085)
        spacing: Math.round(-6 * ui.s)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(ui.now, "ddd MMM d")
            font.family: ui.font
            font.pixelSize: Math.round(25 * ui.s)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.9)
            layer.enabled: true
            layer.effect: DropShadow { radius: 8; samples: 17; color: Qt.rgba(0, 0, 0, 0.25) }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: timeText.width
            height: timeText.height

            Text {
                id: timeText
                // 12-hour without AM/PM, as on macOS.
                text: (ui.now.getHours() % 12 || 12) + ":" + String(ui.now.getMinutes()).padStart(2, "0")
                font.family: ui.font
                font.pixelSize: Math.round(172 * ui.s)
                font.weight: Font.DemiBold
                font.letterSpacing: Math.round(-6 * ui.s)
                color: "white"
                visible: false
            }
            LinearGradient {
                anchors.fill: timeText
                source: timeText
                start: Qt.point(0, 0)
                end: Qt.point(0, height)
                gradient: Gradient {
                    GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.93) }
                    GradientStop { position: 0.9; color: Qt.rgba(0.93, 0.91, 1, 0.78) }
                }
                layer.enabled: true
                layer.effect: DropShadow { radius: 14; samples: 29; verticalOffset: Math.round(2 * ui.s); color: Qt.rgba(0, 0, 0, 0.18) }
            }
        }
    }

    // ---- Session and keyboard (top right, small, like the macOS menu extras)
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.round(9 * ui.s)
        anchors.rightMargin: Math.round(16 * ui.s)
        spacing: Math.round(18 * ui.s)

        Text {
            visible: keyboard.layouts.length > 1
            text: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
            font.family: ui.font
            font.pixelSize: Math.round(13 * ui.s)
            font.weight: Font.DemiBold
            color: "white"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }

        // Session picker: shows the chosen desktop session; click to cycle.
        Text {
            id: sessionLabel
            visible: sessionNames.count > 1
            text: sessionNames.count > ui.sessionIndex && sessionNames.itemAt(ui.sessionIndex) ? sessionNames.itemAt(ui.sessionIndex).sessionName : ""
            font.family: ui.font
            font.pixelSize: Math.round(13 * ui.s)
            font.weight: Font.DemiBold
            color: "white"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ui.sessionIndex = (ui.sessionIndex + 1) % sessionNames.count
            }
            Repeater {
                id: sessionNames
                model: sessionModel
                delegate: Item {
                    readonly property string sessionName: model.name || ""
                }
            }
        }
    }

    // ---- User + password -------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: powerRow.top
        anchors.bottomMargin: Math.round(parent.height * 0.05)
        spacing: Math.round(9 * ui.s)

        // Other accounts, if any: small avatars to switch between.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(14 * ui.s)
            visible: userRepeater.count > 1

            Repeater {
                model: userRepeater.count
                delegate: Avatar {
                    required property int index
                    size: Math.round(34 * ui.s)
                    initial: userRepeater.itemAt(index) ? userRepeater.itemAt(index).displayName : ""
                    picture: userRepeater.itemAt(index) ? userRepeater.itemAt(index).avatar : ""
                    opacity: index === ui.userIndex ? 1 : 0.55
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ui.userIndex = parent.index;
                            passwordField.clear();
                            passwordField.forceActiveFocus();
                        }
                    }
                }
            }
        }

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.round(64 * ui.s)
            initial: ui.userRole("displayName")
            picture: ui.userRole("avatar")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ui.userRole("displayName")
            font.family: ui.font
            font.pixelSize: Math.round(15 * ui.s)
            font.weight: Font.DemiBold
            color: "white"
            layer.enabled: true
            layer.effect: DropShadow { radius: 6; samples: 13; color: Qt.rgba(0, 0, 0, 0.35) }
        }

        Item {
            id: passwordRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: pill.width
            height: pill.height

            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: pill; property: "x"; to: -10 * ui.s; duration: 50 }
                NumberAnimation { target: pill; property: "x"; to: 10 * ui.s; duration: 70 }
                NumberAnimation { target: pill; property: "x"; to: -7 * ui.s; duration: 70 }
                NumberAnimation { target: pill; property: "x"; to: 5 * ui.s; duration: 60 }
                NumberAnimation { target: pill; property: "x"; to: 0; duration: 50 }
            }

            Rectangle {
                id: pill
                width: Math.round(200 * ui.s)
                height: Math.round(30 * ui.s)
                radius: height / 2
                color: ui.glass
                border.color: Qt.rgba(1, 1, 1, passwordField.activeFocus ? 0.35 : 0.2)
                border.width: 1

                QQC2.TextField {
                    id: passwordField
                    objectName: "passwordField"
                    anchors.fill: parent
                    anchors.rightMargin: submitButton.visible ? submitButton.width + Math.round(4 * ui.s) : 0
                    leftPadding: Math.round(12 * ui.s)
                    rightPadding: Math.round(8 * ui.s)
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    placeholderText: "Enter Password"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.3)
                    font.family: ui.font
                    font.pixelSize: Math.round(13 * ui.s)
                    enabled: !ui.busy
                    focus: true
                    background: null
                    onAccepted: ui.login()
                    Component.onCompleted: forceActiveFocus()
                }

                // Circled arrow inside the field once you start typing.
                MouseArea {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(3 * ui.s)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - Math.round(6 * ui.s)
                    height: width
                    visible: passwordField.text.length > 0 || !ui.userRole("passwordNeeded")
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ui.login()

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, parent.containsMouse ? 0.4 : 0.28)
                    }
                    Image {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.6)
                        height: width
                        source: "icons/arrow.svg"
                        sourceSize: Qt.size(width * 2, height * 2)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ui.message !== "" ? ui.message : (keyboard.capsLock ? "Caps Lock is on" : "Enter your password to log in")
            font.family: ui.font
            font.pixelSize: Math.round(11 * ui.s)
            color: Qt.rgba(1, 1, 1, 0.85)
        }
    }

    // ---- Sleep / Restart / Shut Down, as on the macOS login window -------
    Row {
        id: powerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.045)
        spacing: Math.round(34 * ui.s)

        PowerButton { label: "Sleep"; icon: "icons/sleep.svg"; visible: sddm.canSuspend; onActivated: sddm.suspend() }
        PowerButton { label: "Restart"; icon: "icons/restart.svg"; visible: sddm.canReboot; onActivated: sddm.reboot() }
        PowerButton { label: "Shut Down"; icon: "icons/shutdown.svg"; visible: sddm.canPowerOff; onActivated: sddm.powerOff() }
    }

    component Avatar: Item {
        property real size: 64
        property string initial: ""
        property string picture: ""
        width: size
        height: size

        Rectangle {
            id: mask
            anchors.fill: parent
            radius: width / 2
            visible: false
        }
        Image {
            id: photo
            anchors.fill: parent
            source: parent.picture !== "" ? parent.picture : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        OpacityMask {
            anchors.fill: parent
            source: photo
            maskSource: mask
            visible: photo.status === Image.Ready
        }
        // No picture: gray circle with the user's initial, like macOS.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: photo.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "#a5a5ab" }
                GradientStop { position: 1; color: "#6e6e75" }
            }
            Text {
                anchors.centerIn: parent
                text: parent.parent.initial.charAt(0).toUpperCase()
                font.family: ui.font
                font.pixelSize: parent.height * 0.45
                font.weight: Font.DemiBold
                color: "white"
            }
        }
    }

    component PowerButton: MouseArea {
        id: button
        property string label
        property string icon
        signal activated()

        width: Math.round(64 * ui.s)
        height: column.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: activated()

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(6 * ui.s)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(36 * ui.s)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, button.containsMouse ? 0.32 : 0.2)
                border.color: Qt.rgba(1, 1, 1, 0.25)
                Image {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.5)
                    height: width
                    source: button.icon
                    sourceSize: Qt.size(width * 2, height * 2)
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.label
                font.family: ui.font
                font.pixelSize: Math.round(11 * ui.s)
                color: Qt.rgba(1, 1, 1, button.containsMouse ? 1 : 0.85)
            }
        }
    }
}
