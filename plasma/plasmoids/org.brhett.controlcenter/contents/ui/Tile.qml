import QtQuick
import org.kde.kirigami as Kirigami

// Rounded translucent Control Center tile.
Rectangle {
    default property alias content: inner.data
    property int padding: Kirigami.Units.mediumSpacing

    radius: Kirigami.Units.gridUnit * 0.8
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    border.width: 1

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.padding
    }
}
