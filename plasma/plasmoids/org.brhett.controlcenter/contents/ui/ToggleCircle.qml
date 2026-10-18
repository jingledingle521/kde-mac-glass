import QtQuick
import org.kde.kirigami as Kirigami

// Round toggle: accent blue with a white glyph when on, grey when off.
MouseArea {
    id: toggle

    property bool checked: false
    property string iconName: ""

    implicitWidth: Math.round(Kirigami.Units.gridUnit * 1.7)
    implicitHeight: implicitWidth
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: toggle.checked ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        opacity: toggle.pressed ? 0.7 : 1
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.55)
        height: width
        source: toggle.iconName
        isMask: true
        color: toggle.checked ? "white" : Kirigami.Theme.textColor
    }
}
