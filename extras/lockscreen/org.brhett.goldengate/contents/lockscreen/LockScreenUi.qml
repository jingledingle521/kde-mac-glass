import QtQml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.battery
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.sessions
import org.kde.kirigami as Kirigami

// macOS-style lock screen: date and large clock at the top, status icons in
// the top-right corner, avatar + pill password field at the bottom.
Item {
    id: ui

    // Sizes are designed for a 1707x1067 logical screen and scale from there.
    readonly property real s: Math.max(0.6, Math.min(width / 1707, height / 1067))
    readonly property string displayFont: "Inter"
    readonly property string textFont: "Inter"
    readonly property color glass: Qt.rgba(1, 1, 1, 0.22)
    property bool noPasswordUnlock: false
    property var now: new Date()

    // Animation state: the photo fades in from black, then the clock and the
    // user block ease into place. Unlocking runs it in reverse before exiting.
    property real blackout: 1
    property real clockIn: 0
    property real userIn: 0

    function finishUnlock() {
        intro.stop();
        outro.start();
        // Never let the fade decide whether we unlock: animations stall when
        // the window isn't being drawn (e.g. while the display wakes up).
        quitFallback.start();
    }

    function handleMessage(msg) {
        if (!msg) {
            return;
        }
        if (!root.notification) {
            root.notification = msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg;
        }
    }

    function submit() {
        if (passwordField.text.length > 0 && passwordField.enabled) {
            authenticator.respond(passwordField.text);
        }
    }

    // macOS shows 12-hour time without AM/PM on the lock screen. Qt's "h"
    // is only 12-hour when the format also contains AP, so build it by hand.
    readonly property string timeText: (now.getHours() % 12 || 12) + ":" + String(now.getMinutes()).padStart(2, "0")

    function layoutLabel(shortName) {
        return shortName.toLowerCase() === "us" ? "U.S." : shortName.toUpperCase();
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Component.onCompleted: {
        authenticator.startAuthenticating();
        passwordField.forceActiveFocus();
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // non-interactive authenticators (fingerprint, smartcard)
                return;
            }
            ui.handleMessage(i18nd("plasma_shell_org.kde.plasma.desktop", "Incorrect password"));
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            shake.restart();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                ui.finishUnlock();
            } else {
                ui.noPasswordUnlock = true;
            }
        }
        function onInfoMessageChanged() {
            ui.handleMessage(authenticator.infoMessage);
        }
        function onErrorMessageChanged() {
            ui.handleMessage(authenticator.errorMessage);
        }
        function onPromptChanged(msg) {
            ui.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged(msg) {
            passwordField.forceActiveFocus();
        }
    }

    Connections {
        target: root
        function onClearPassword() {
            passwordField.clear();
            passwordField.forceActiveFocus();
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    BatteryControlModel {
        id: batteryControl
    }

    PlasmaNM.ConnectionIcon {
        id: connectionIcon
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ui.now = new Date()
    }

    Timer {
        id: notificationRemoveTimer
        interval: 3000
        onTriggered: root.notification = ""
    }

    Timer {
        id: quitFallback
        interval: 900
        onTriggered: Qt.quit()
    }

    Timer {
        id: graceLockTimer
        // Must outlast PAM's ~2 s fail delay: restarting authentication
        // inside it is ignored ("attempt too soon") and the next password
        // goes nowhere. Stock Plasma uses 3 s too.
        interval: 3000
        onTriggered: {
            root.clearPassword();
            authenticator.startAuthenticating();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPressed: passwordField.forceActiveFocus()
        Window.onWindowChanged: if (Window.window) Window.window.requestActivate()
    }

    // Soft darkening at the top and bottom keeps white text legible on any wallpaper.
    LinearGradient {
        anchors.fill: parent
        start: Qt.point(0, 0)
        end: Qt.point(0, height)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
        }
    }

    ParallelAnimation {
        id: intro
        running: true
        NumberAnimation { target: ui; property: "blackout"; to: 0; duration: 550; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: ui; property: "clockIn"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 380 }
            NumberAnimation { target: ui; property: "userIn"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: outro
        ParallelAnimation {
            NumberAnimation { target: ui; property: "userIn"; to: 0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: ui; property: "clockIn"; to: 0; duration: 280; easing.type: Easing.InCubic }
        }
        NumberAnimation { target: ui; property: "blackout"; to: 1; duration: 300; easing.type: Easing.InQuad }
        ScriptAction { script: Qt.quit() }
    }

    // ---- Clock -----------------------------------------------------------
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.085)
        spacing: Math.round(-6 * ui.s)
        opacity: ui.clockIn
        transform: Translate { y: (1 - ui.clockIn) * -16 * ui.s }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(ui.now, "ddd MMM d")
            font.family: ui.textFont
            font.pixelSize: Math.round(25 * ui.s)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.9)
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 8
                samples: 17
                color: Qt.rgba(0, 0, 0, 0.25)
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: timeText.width
            height: timeText.height

            Text {
                id: timeText
                text: ui.timeText
                font.family: ui.displayFont
                font.pixelSize: Math.round(172 * ui.s)
                font.weight: Font.DemiBold
                font.letterSpacing: Math.round(-6 * ui.s)
                color: "white"
                visible: false
            }
            // Frosted, slightly translucent digits like the macOS clock.
            LinearGradient {
                id: timeGlass
                anchors.fill: timeText
                source: timeText
                start: Qt.point(0, 0)
                end: Qt.point(0, height)
                gradient: Gradient {
                    GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.93) }
                    GradientStop { position: 0.9; color: Qt.rgba(0.93, 0.91, 1, 0.78) }
                }
                layer.enabled: true
                layer.effect: DropShadow {
                    radius: 14
                    samples: 29
                    verticalOffset: Math.round(2 * ui.s)
                    color: Qt.rgba(0, 0, 0, 0.18)
                }
            }
        }
    }

    // ---- Top-right status icons -------------------------------------------
    RowLayout {
        id: statusBar
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.round(9 * ui.s)
        anchors.rightMargin: Math.round(16 * ui.s)
        spacing: Math.round(18 * ui.s)
        opacity: ui.clockIn

        RowLayout {
            spacing: Math.round(6 * ui.s)
            PW.KeyboardLayoutSwitcher {
                id: keyboardLayoutSwitcher
                Layout.preferredWidth: layoutLabel.implicitWidth
                Layout.preferredHeight: layoutLabel.implicitHeight
                acceptedButtons: Qt.LeftButton
                onClicked: keyboardLayout.switchToNextLayout()

                Text {
                    id: layoutLabel
                    text: ui.layoutLabel(keyboardLayoutSwitcher.layoutNames.shortName)
                    font.family: ui.textFont
                    font.pixelSize: Math.round(13 * ui.s)
                    font.weight: Font.DemiBold
                    color: "white"
                }
            }
            Kirigami.Icon {
                Layout.preferredWidth: Math.round(16 * ui.s)
                Layout.preferredHeight: Math.round(16 * ui.s)
                source: "input-keyboard-symbolic"
                color: "white"
                isMask: true
            }
        }

        // Horizontal battery glyph with a fill level, as on macOS.
        Item {
            visible: batteryControl.hasInternalBatteries
            Layout.preferredWidth: Math.round(27 * ui.s)
            Layout.preferredHeight: Math.round(13 * ui.s)

            Rectangle {
                id: batteryBody
                width: parent.width - Math.round(3 * ui.s)
                height: parent.height
                radius: Math.round(4 * ui.s)
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.55)
                border.width: Math.max(1, Math.round(1.2 * ui.s))

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Math.round(2 * ui.s)
                    width: Math.max(2, (parent.width - 2 * anchors.margins) * batteryControl.percent / 100)
                    radius: Math.round(2 * ui.s)
                    color: batteryControl.percent <= 10 && !batteryControl.pluggedIn ? "#ff453a" : "white"
                }
            }
            Rectangle {
                anchors.left: batteryBody.right
                anchors.leftMargin: Math.max(1, Math.round(1 * ui.s))
                anchors.verticalCenter: batteryBody.verticalCenter
                width: Math.round(2 * ui.s)
                height: Math.round(5 * ui.s)
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.55)
            }
            Kirigami.Icon {
                anchors.centerIn: batteryBody
                width: Math.round(11 * ui.s)
                height: width
                source: "battery-charging-symbolic"
                visible: batteryControl.pluggedIn && batteryControl.percent < 100
                color: "black"
                isMask: true
            }
        }

        Kirigami.Icon {
            Layout.preferredWidth: Math.round(17 * ui.s)
            Layout.preferredHeight: Math.round(17 * ui.s)
            source: connectionIcon.connectionIcon
            color: "white"
            isMask: true
        }

        MouseArea {
            id: powerButton
            Layout.preferredWidth: Math.round(17 * ui.s)
            Layout.preferredHeight: Math.round(17 * ui.s)
            cursorShape: Qt.PointingHandCursor
            onClicked: powerMenu.opened ? powerMenu.close() : powerMenu.open()

            Kirigami.Icon {
                anchors.fill: parent
                source: "system-shutdown-symbolic"
                color: "white"
                isMask: true
            }

            PlasmaComponents3.Menu {
                id: powerMenu
                y: powerButton.height + Math.round(8 * ui.s)
                x: powerButton.width - width

                PlasmaComponents3.MenuItem {
                    text: i18nd("plasma_shell_org.kde.plasma.desktop", "Sleep")
                    visible: sessionManagement.canSuspend
                    onClicked: sessionManagement.suspend()
                }
                PlasmaComponents3.MenuItem {
                    text: i18nd("plasma_shell_org.kde.plasma.desktop", "Restart")
                    visible: sessionManagement.canReboot
                    onClicked: sessionManagement.requestReboot(0)
                }
                PlasmaComponents3.MenuItem {
                    text: i18nd("plasma_shell_org.kde.plasma.desktop", "Shut Down")
                    visible: sessionManagement.canShutdown
                    onClicked: sessionManagement.requestShutdown(0)
                }
            }
        }
    }

    // ---- User + password -------------------------------------------------
    Column {
        id: userBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.1)
        spacing: Math.round(9 * ui.s)
        opacity: ui.userIn
        transform: Translate { y: (1 - ui.userIn) * 20 * ui.s }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(50 * ui.s)
            height: width

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
            }
            Image {
                id: avatarImage
                anchors.fill: parent
                source: kscreenlocker_userImage !== "" ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            OpacityMask {
                anchors.fill: parent
                source: avatarImage
                maskSource: avatarMask
                visible: avatarImage.status === Image.Ready
            }
            // No picture set: gray circle with the user's initial, like macOS.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: avatarImage.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0; color: "#a5a5ab" }
                    GradientStop { position: 1; color: "#6e6e75" }
                }
                Text {
                    anchors.centerIn: parent
                    text: kscreenlocker_userName.charAt(0).toUpperCase()
                    font.family: ui.textFont
                    font.pixelSize: parent.height * 0.45
                    font.weight: Font.DemiBold
                    color: "white"
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: kscreenlocker_userName
            font.family: ui.textFont
            font.pixelSize: Math.round(15 * ui.s)
            font.weight: Font.DemiBold
            color: "white"
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 6
                samples: 13
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        Item {
            id: passwordRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: pill.width
            height: pill.height
            visible: !ui.noPasswordUnlock

            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: pill; property: "x"; to: -12 * ui.s; duration: 50 }
                NumberAnimation { target: pill; property: "x"; to: 12 * ui.s; duration: 70 }
                NumberAnimation { target: pill; property: "x"; to: -9 * ui.s; duration: 70 }
                NumberAnimation { target: pill; property: "x"; to: 6 * ui.s; duration: 60 }
                NumberAnimation { target: pill; property: "x"; to: 0; duration: 50 }
            }

            Rectangle {
                id: pill
                width: Math.round(176 * ui.s)
                height: Math.round(28 * ui.s)
                radius: height / 2
                color: ui.glass
                border.color: Qt.rgba(1, 1, 1, passwordField.activeFocus ? 0.35 : 0.2)
                border.width: 1

                QQC2.TextField {
                    id: passwordField
                    anchors.fill: parent
                    anchors.rightMargin: submitButton.visible ? submitButton.width + Math.round(4 * ui.s) : 0
                    leftPadding: Math.round(12 * ui.s)
                    rightPadding: Math.round(8 * ui.s)
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    placeholderText: i18nd("plasma_shell_org.kde.plasma.desktop", "Enter Password")
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.3)
                    font.family: ui.textFont
                    font.pixelSize: Math.round(13 * ui.s)
                    enabled: !graceLockTimer.running
                    focus: true
                    background: null

                    onAccepted: ui.submit()
                    Keys.onEscapePressed: event => {
                        if (text.length > 0) {
                            clear();
                        } else {
                            event.accepted = false;
                        }
                    }
                }

                // Circled arrow appears inside the field once you start typing.
                MouseArea {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(3 * ui.s)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - Math.round(6 * ui.s)
                    height: width
                    visible: passwordField.text.length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ui.submit()

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.3)
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.6
                        height: width
                        source: "go-next-symbolic"
                        color: "white"
                        isMask: true
                    }
                }
            }

            // "?" sits outside the pill so the field itself stays centered.
            MouseArea {
                id: hintButton
                anchors.left: pill.right
                anchors.leftMargin: Math.round(9 * ui.s)
                anchors.verticalCenter: pill.verticalCenter
                width: Math.round(20 * ui.s)
                height: width
                cursorShape: Qt.PointingHandCursor
                onClicked: hintVisible = !hintVisible

                property bool hintVisible: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.75)
                    border.width: Math.max(1, Math.round(1.2 * ui.s))
                }
                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.family: ui.textFont
                    font.pixelSize: Math.round(12 * ui.s)
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
            }
        }

        PlasmaComponents3.Button {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ui.noPasswordUnlock
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Unlock")
            onClicked: ui.finishUnlock()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(200 * ui.s)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: ui.textFont
            font.pixelSize: Math.round(11 * ui.s)
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.85)
            text: {
                const parts = [];
                if (capsLockState.locked) {
                    parts.push(i18nd("plasma_shell_org.kde.plasma.desktop", "Caps Lock is on"));
                }
                if (root.notification) {
                    parts.push(root.notification);
                }
                if (parts.length > 0) {
                    return parts.join("\n");
                }
                if (hintButton.hintVisible) {
                    return i18nd("plasma_shell_org.kde.plasma.desktop", "Enter the password you use to log in to Fedora");
                }
                return i18nd("plasma_shell_org.kde.plasma.desktop", "Your password is required to unlock");
            }
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 6
                samples: 13
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }
    }

    Loader {
        z: 2
        active: root.viewVisible
        source: "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockOsd.qml"
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Kirigami.Units.gridUnit
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 100
        color: "black"
        opacity: ui.blackout
        visible: opacity > 0
    }
}
