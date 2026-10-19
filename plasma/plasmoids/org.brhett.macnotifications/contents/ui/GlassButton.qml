import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// A small glass capsule ("Show Less", "Clear All", an action). With no text
// it is a round ⓧ; `expandText` turns the ⓧ into a captioned capsule on hover,
// as macOS's Clear All does.
GlassCard {
    id: button

    property string text
    property string expandText
    property bool closeIcon: false
    readonly property bool showText: text !== "" || (expandText !== "" && mouse.containsMouse)
    readonly property int size: 26

    signal clicked()

    radius: height / 2
    strength: 1.15
    hovered: mouse.containsMouse
    implicitWidth: showText ? label.implicitWidth + 24 : size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: 12
        height: 12
        visible: !button.showText && button.closeIcon
        source: "window-close-symbolic"
        isMask: true
        color: Kirigami.Theme.textColor
    }

    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        visible: button.showText
        text: button.text || button.expandText
        font.weight: Font.DemiBold
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        textFormat: Text.PlainText
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
